# frozen_string_literal: true

require 'spec_helper'

describe SecurityAuditLogsController, type: :controller do
  render_views
  fixtures :users

  before do
    @controller = SecurityAuditLogsController.new
    @request = ActionDispatch::TestRequest.create
    @response = ActionDispatch::TestResponse.new
    User.current = nil
    @request.session = ActionController::TestSession.new
    @request.session[:user_id] = 1 # admin
    User.find(1).update_columns(sudoer: true)
  end

  describe "GET index" do
    it "renders successfully with no audit logs" do
      get :index
      assert_response :success
    end

    it "renders successfully with audit logs" do
      admin = User.find(1)
      SecurityAuditLog.log(action: "sudo_activated", user: admin, remote_ip: "127.0.0.1")
      SecurityAuditLog.log(action: "user_updated", user: admin, entity_type: "User", entity_name: "jsmith", details: "admin changed")

      get :index
      assert_response :success
    end

    it "renders pagination without error when multiple pages exist" do
      admin = User.find(1)
      30.times { |i| SecurityAuditLog.log(action: "test_action_#{i}", user: admin, remote_ip: "127.0.0.1") }

      get :index, params: { per_page: 10 }
      assert_response :success
      expect(response.body).to include('class="pagination"')
    end

    it "filters by action" do
      admin = User.find(1)
      SecurityAuditLog.log(action: "sudo_activated", user: admin)
      SecurityAuditLog.log(action: "user_updated", user: admin)

      get :index, params: { action_filter: "sudo_activated" }
      assert_response :success
      # Check table rows (audit-action spans), not the filter dropdown which lists all actions
      expect(response.body).to include('<span class="audit-action">Sudo activated</span>')
      expect(response.body).not_to include('<span class="audit-action">User updated</span>')
    end

    it "filters by search query" do
      admin = User.find(1)
      SecurityAuditLog.log(action: "sudo_activated", user: admin, details: "unique_search_term")
      SecurityAuditLog.log(action: "user_updated", user: admin, details: "other_details")

      get :index, params: { q: "unique_search_term" }
      assert_response :success
    end

    it "denies access to non-admin users" do
      @request.session[:user_id] = 2 # non-admin
      get :index
      assert_response 403
    end
  end
end
