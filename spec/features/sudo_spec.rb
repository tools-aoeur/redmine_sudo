require "spec_helper"

describe "Sudo", type: :request do
  fixtures :users, :roles

  include ActiveSupport::Testing::TimeHelpers

  # taken from core
  def log_user(login, password)
    User.anonymous
    get "/login"
    assert_equal nil, session[:user_id]
    assert_response :success
    post "/login", params: { username: login, password: password }
    assert_equal login, User.find(session[:user_id]).login
  end

  def elevated?
    session[:sudo_admin_user_id].present?
  end

  after do
    travel_back
  end

  context "toggle link" do
    it "should route to sudo#toggle" do
      assert_routing(
        { method: :post, path: "/sudo/toggle" },
        { controller: "sudo", action: "toggle" }
      )
    end

    it "elevates the session without ever touching the admin column" do
      user = User.find_by_login("jsmith")
      user.update_columns(admin: false, sudoer: true)
      log_user("jsmith", "jsmith")
      updated_on_before = user.reload.updated_on

      post "/sudo/toggle", params: { back_url: "/my/page" }

      expect(response).to redirect_to("/my/page")
      expect(elevated?).to eq true
      user.reload
      expect(user.read_attribute(:admin)).to eq false
      expect(user.sudoer?).to eq true
      expect(user.updated_on).to eq updated_on_before
    end

    it "drops the elevation again without touching the admin column" do
      user = User.find_by_login("jsmith")
      user.update_columns(admin: false, sudoer: true)
      log_user("jsmith", "jsmith")
      post "/sudo/toggle"
      expect(elevated?).to eq true
      updated_on_before = user.reload.updated_on

      post "/sudo/toggle", params: { back_url: "/my/page" }

      expect(response).to redirect_to("/my/page")
      expect(elevated?).to eq false
      user.reload
      expect(user.read_attribute(:admin)).to eq false
      expect(user.updated_on).to eq updated_on_before
    end

    it "should deny toggle to non-sudoer" do
      user = User.find_by_login("jsmith")
      user.update_columns(admin: false, sudoer: false)
      log_user("jsmith", "jsmith")

      post "/sudo/toggle", params: { back_url: "/my/page" }
      expect(response).to have_http_status(403)
    end

    it "denies the toggle when the admin column is set, leaving nothing to elevate" do
      user = User.find_by_login("admin")
      user.update_columns(admin: true, sudoer: true)
      log_user("admin", "admin")

      post "/sudo/toggle", params: { back_url: "/my/page" }

      expect(response).to have_http_status(403)
      expect(user.reload.read_attribute(:admin)).to eq true
    end

    it "should not allow a redirection to a different domain name" do
      post "/sudo/toggle", params: { back_url: ".my-custom-domain-name.com" }
      expect(response).to_not redirect_to("my-custom-domain-name.com")
    end
  end

  context "session isolation" do
    it "does not leak an elevation from one session to another" do
      user = User.find_by_login("jsmith")
      user.update_columns(admin: false, sudoer: true)

      first = open_session
      first.post "/login", params: { username: "jsmith", password: "jsmith" }
      first.post "/sudo/toggle"
      expect(first.session[:sudo_admin_user_id]).to eq user.id

      second = open_session
      second.post "/login", params: { username: "jsmith", password: "jsmith" }
      expect(second.session[:sudo_admin_user_id]).to be_nil

      # the fresh session is a plain user and cannot reach an admin screen...
      second.get "/users"
      expect(second.response).to have_http_status(403)

      # ...while the first session is still elevated.
      first.get "/users"
      expect(first.response).to have_http_status(:success)
    end

    it "does not let one session drop the elevation of another" do
      user = User.find_by_login("jsmith")
      user.update_columns(admin: false, sudoer: true)

      first = open_session
      first.post "/login", params: { username: "jsmith", password: "jsmith" }
      first.post "/sudo/toggle"

      second = open_session
      second.post "/login", params: { username: "jsmith", password: "jsmith" }
      second.post "/sudo/toggle" # elevate
      second.post "/sudo/toggle" # and drop again

      expect(second.session[:sudo_admin_user_id]).to be_nil
      expect(first.session[:sudo_admin_user_id]).to eq user.id
      first.get "/users"
      expect(first.response).to have_http_status(:success)
    end
  end

  context "non-session authentication" do
    before do
      Setting.rest_api_enabled = "1"
    end

    let(:sudoer) do
      user = User.find_by_login("jsmith")
      user.update_columns(admin: false, sudoer: true)
      user.api_key # generates the token if needed
      user
    end

    it "never elevates an API key request, even while a browser session is elevated" do
      key = sudoer.api_key
      log_user("jsmith", "jsmith")
      post "/sudo/toggle"
      expect(elevated?).to eq true

      # /users.json is admin-only
      get "/users.json", params: { key: key }
      expect(response).to have_http_status(403)
    end

    it "does not revoke an elevation held by a browser session" do
      key = sudoer.api_key

      browser = open_session
      browser.post "/login", params: { username: "jsmith", password: "jsmith" }
      browser.post "/sudo/toggle"

      api = open_session
      api.get "/issues.json", params: { key: key }
      api.get "/projects.atom", params: { key: key }
      api.get "/my/page", params: { key: key } # API key on an HTML endpoint

      expect(browser.session[:sudo_admin_user_id]).to eq sudoer.id
      browser.get "/users"
      expect(browser.response).to have_http_status(:success)
    end

    it "keeps the admin column privileged over the API" do
      user = User.find_by_login("admin")
      user.update_columns(admin: true, sudoer: false)

      get "/users.json", params: { key: user.api_key }
      expect(response).to have_http_status(:success)
    end
  end

  context "core sudo mode integration" do
    before do
      allow(Redmine::SudoMode).to receive(:enabled?).and_return(true)
    end

    it "requires a core sudo password reconfirmation once the login-granted window has passed" do
      user = User.find_by_login("admin")
      user.update_columns(admin: false, sudoer: true)
      log_user("admin", "admin") # login itself grants a fresh sudo window
      travel 20.minutes # let that window pass

      post "/sudo/toggle", params: { back_url: "/my/page" }
      expect(response).to have_http_status(:success) # renders the password form
      expect(elevated?).to eq false

      post "/sudo/toggle", params: { back_url: "/my/page", sudo_password: "admin" }
      expect(response).to redirect_to("/my/page")
      expect(elevated?).to eq true
      expect(user.reload.read_attribute(:admin)).to eq false
    end

    it "becoming user forces the next become-admin attempt to reconfirm the password" do
      user = User.find_by_login("admin")
      user.update_columns(admin: false, sudoer: true)
      log_user("admin", "admin") # login itself grants a fresh sudo window

      post "/sudo/toggle", params: {} # become admin, no password needed yet (still within window)
      expect(elevated?).to eq true

      post "/sudo/toggle", params: {} # become user
      expect(elevated?).to eq false

      post "/sudo/toggle", params: {} # become admin again, no password given
      expect(response).to have_http_status(:success) # password form again, not elevated
      expect(elevated?).to eq false
    end

    it "does not extend the core sudo session on ordinary (non-sudo-gated) browsing" do
      user = User.find_by_login("admin")
      user.update_columns(admin: false, sudoer: true)
      log_user("admin", "admin") # login itself sets session[:sudo_timestamp]
      post "/sudo/toggle"
      timestamp_after_login = session[:sudo_timestamp]
      expect(timestamp_after_login).not_to be_nil

      get "/my/page" # ordinary page, not require_sudo_mode-gated

      expect(session[:sudo_timestamp]).to eq timestamp_after_login
      expect(elevated?).to eq true
    end

    it "extends the core sudo session on require_admin-gated auxiliary admin screens" do
      user = User.find_by_login("admin")
      user.update_columns(admin: false, sudoer: true)
      log_user("admin", "admin") # login itself sets session[:sudo_timestamp]
      post "/sudo/toggle"
      timestamp_after_login = session[:sudo_timestamp]
      expect(timestamp_after_login).not_to be_nil

      travel 5.minutes
      get "/enumerations/new" # require_admin-gated, but not require_sudo_mode-gated

      expect(session[:sudo_timestamp]).to be > timestamp_after_login
      expect(elevated?).to eq true

      # ... and that slid session keeps the admin from auto-dropping later,
      # even though it's now more than sudo_mode_timeout past the login.
      travel 12.minutes
      get "/my/page"
      expect(elevated?).to eq true
    end

    it "auto-drops the elevation and logs sudo_expired once the core sudo session is invalid" do
      user = User.find_by_login("admin")
      user.update_columns(admin: false, sudoer: true)
      log_user("admin", "admin")
      post "/sudo/toggle"
      expect(elevated?).to eq true
      updated_on_before = user.reload.updated_on

      travel 20.minutes # let the window expire

      expect do
        get "/my/page"
      end.to change { SecurityAuditLog.where(action: 'sudo_expired').count }.by(1)

      expect(elevated?).to eq false
      user.reload
      expect(user.read_attribute(:admin)).to eq false
      expect(user.sudoer?).to eq true
      expect(user.updated_on).to eq updated_on_before
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
      expect(elevated?).to eq true
    end

    it "returns to the page the user came from after the password reconfirmation" do
      # Regression test: the referer captured on the *first* POST is the page
      # the user actually clicked "Become Admin" from. It has to be turned into
      # a back_url before core renders its password form, because core only
      # round-trips the params it sees at that point as hidden fields. Setting
      # it after `require_sudo_mode` lost it, and the resubmit (whose referer is
      # /sudo/toggle itself) then silently fell back to the /my/page default.
      user = User.find_by_login("admin")
      user.update_columns(admin: false, sudoer: true)
      log_user("admin", "admin") # login itself grants a fresh sudo window
      travel 20.minutes # let that window pass

      post "/sudo/toggle", headers: { "HTTP_REFERER" => "http://www.example.com/projects" }
      expect(response).to have_http_status(:success) # renders the password form
      expect(response.body).to include('name="back_url"')
      expect(response.body).to include('value="http://www.example.com/projects"')

      post "/sudo/toggle",
        params: { sudo_password: "admin", back_url: "http://www.example.com/projects" },
        headers: { "HTTP_REFERER" => "http://www.example.com/sudo/toggle" }

      expect(response).to redirect_to("/projects")
      expect(elevated?).to eq true
    end
  end
end
