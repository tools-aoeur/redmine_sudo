require "spec_helper"

describe "Sudo", type: :request do
  fixtures :users, :roles

  # taken from core
  def log_user(login, password)
    User.anonymous
    get "/login"
    assert_equal nil, session[:user_id]
    assert_response :success
    post "/login", params: { username: login, password: password }
    assert_equal login, User.find(session[:user_id]).login
  end

  context "toggle link" do
    it "should route to sudo#toggle" do
      assert_routing(
        { method: :post, path: "/sudo/toggle" },
        { controller: "sudo", action: "toggle" }
      )
    end

    it "should toggle admin without changing sudoer" do
      user = User.find_by_login("admin")
      user.update_columns(admin: true, sudoer: true)
      log_user("admin", "admin")

      assert user.reload.read_attribute(:admin)
      assert user.reload.sudoer?

      post "/sudo/toggle", params: { back_url: "/my/page" }
      expect(response).to redirect_to("/my/page")
      user.reload
      assert !user.read_attribute(:admin), "admin should be toggled off"
      assert user.sudoer?, "sudoer should remain true"
    end

    it "should deny toggle to non-sudoer" do
      user = User.find_by_login("jsmith")
      user.update_columns(admin: false, sudoer: false)
      log_user("jsmith", "jsmith")

      post "/sudo/toggle", params: { back_url: "/my/page" }
      expect(response).to have_http_status(403)
    end

    it "should not allow a redirection to a different domain name" do
      post "/sudo/toggle", params: { back_url: ".my-custom-domain-name.com" }
      expect(response).to_not redirect_to("my-custom-domain-name.com")
    end
  end

  context "core sudo mode integration" do
    include ActiveSupport::Testing::TimeHelpers

    before do
      allow(Redmine::SudoMode).to receive(:enabled?).and_return(true)
    end

    after do
      travel_back
    end

    it "requires a core sudo password reconfirmation once the login-granted window has passed" do
      user = User.find_by_login("admin")
      user.update_columns(admin: false, sudoer: true)
      log_user("admin", "admin") # login itself grants a fresh sudo window
      travel 20.minutes # let that window pass

      post "/sudo/toggle", params: { back_url: "/my/page" }
      expect(response).to have_http_status(:success) # renders the password form
      expect(user.reload.read_attribute(:admin)).to eq false

      post "/sudo/toggle", params: { back_url: "/my/page", sudo_password: "admin" }
      expect(response).to redirect_to("/my/page")
      expect(user.reload.read_attribute(:admin)).to eq true
    end

    it "becoming user forces the next become-admin attempt to reconfirm the password" do
      user = User.find_by_login("admin")
      user.update_columns(admin: false, sudoer: true)
      log_user("admin", "admin") # login itself grants a fresh sudo window

      post "/sudo/toggle", params: {} # become admin, no password needed yet (still within window)
      expect(user.reload.read_attribute(:admin)).to eq true

      post "/sudo/toggle", params: {} # become user
      expect(user.reload.read_attribute(:admin)).to eq false

      post "/sudo/toggle", params: {} # become admin again, no password given
      expect(response).to have_http_status(:success) # password form again, not elevated
      expect(user.reload.read_attribute(:admin)).to eq false
    end

    it "does not extend the core sudo session on ordinary (non-sudo-gated) browsing" do
      user = User.find_by_login("admin")
      user.update_columns(admin: true, sudoer: true)
      log_user("admin", "admin") # login itself sets session[:sudo_timestamp]
      timestamp_after_login = session[:sudo_timestamp]
      expect(timestamp_after_login).not_to be_nil

      get "/my/page" # ordinary page, not require_sudo_mode-gated

      expect(session[:sudo_timestamp]).to eq timestamp_after_login
      expect(user.reload.read_attribute(:admin)).to eq true
    end

    it "auto-drops admin and logs sudo_expired once the core sudo session is invalid" do
      user = User.find_by_login("admin")
      user.update_columns(admin: true, sudoer: true)
      log_user("admin", "admin")
      travel 20.minutes # let the login-granted window expire

      expect do
        get "/my/page"
      end.to change { SecurityAuditLog.where(action: 'sudo_expired').count }.by(1)

      user.reload
      expect(user.read_attribute(:admin)).to eq false
      expect(user.sudoer?).to eq true
    end

    it "does not auto-drop admin for API/token requests" do
      user = User.find_by_login("admin")
      user.update_columns(admin: true, sudoer: true)
      log_user("admin", "admin")
      travel 20.minutes

      expect do
        get "/users/current.json"
      end.not_to change { SecurityAuditLog.where(action: 'sudo_expired').count }

      expect(user.reload.read_attribute(:admin)).to eq true
    end

    it "does not blow up with a routing error when the password form is resubmitted to itself" do
      # Regression test: core's sudo_mode/new form posts back to the same URL
      # it was rendered from. When the user is on the /sudo/toggle page and
      # resubmits the password, the browser sends a Referer of /sudo/toggle
      # itself (no back_url param is ever sent by the real menu link). Using
      # that referer as back_url used to make redirect_back_or_default issue
      # a GET redirect to a POST-only route, raising
      # "No route matches [GET] "/sudo/toggle"".
      user = User.find_by_login("admin")
      user.update_columns(admin: false, sudoer: true)
      log_user("admin", "admin") # login itself grants a fresh sudo window
      travel 20.minutes # let that window pass

      post "/sudo/toggle", headers: { "HTTP_REFERER" => "http://www.example.com/my/page" }
      expect(response).to have_http_status(:success) # renders the password form

      post "/sudo/toggle",
        params: { sudo_password: "admin" },
        headers: { "HTTP_REFERER" => "http://www.example.com/sudo/toggle" }

      expect(response).to redirect_to("/my/page")
      expect(user.reload.read_attribute(:admin)).to eq true
    end
  end
end

