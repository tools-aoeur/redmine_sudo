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

    it "should toggle sudoer without changing admin" do
      user = User.find_by_login("admin")
      user.update_columns(admin: true, sudoer: true)
      log_user("admin", "admin")

      assert user.reload.read_attribute(:admin)
      assert user.reload.sudoer?

      post "/sudo/toggle", params: { back_url: "/my/page" }
      expect(response).to redirect_to("/my/page")
      user.reload
      assert user.read_attribute(:admin), "admin column should remain true"
      assert !user.sudoer?, "sudoer should be toggled off"

      post "/sudo/toggle", params: { back_url: "/my/page" }
      expect(response).to redirect_to("/my/page")
      user.reload
      assert user.read_attribute(:admin), "admin column should still remain true"
      assert user.sudoer?, "sudoer should be toggled back on"
    end

    it "should deny toggle to non-permanent-admin" do
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
end
