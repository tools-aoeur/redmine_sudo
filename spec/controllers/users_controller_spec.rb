require 'spec_helper'

describe UsersController, type: :controller do
  render_views
  fixtures :users

  let!(:user_7) { User.find(7) }

  before do
    @controller = UsersController.new
    @request = ActionDispatch::TestRequest.create
    @response = ActionDispatch::TestResponse.new
    User.current = nil
    @request.session = ActionController::TestSession.new
    @request.session[:user_id] = 1 # permissions admin
    User.find(1).update_columns(admin: true) # ensure admin? (require_admin) passes
  end

  describe "POST update" do
    it "sets sudoer independently of admin when submitted by an admin" do
      user_7.update_columns(admin: false, sudoer: false)

      patch :update, :params => { :id => 7, :user => { sudoer: '1', mail: "test7@example.net" } }

      user_7.reload
      expect(user_7.sudoer?).to eq true
      expect(user_7.read_attribute(:admin)).to eq false
    end

    it "clears sudoer independently of admin when submitted by an admin" do
      user_7.update_columns(admin: true, sudoer: true)

      patch :update, :params => { :id => 7, :user => { sudoer: '0', mail: "test7@example.net" } }

      user_7.reload
      expect(user_7.sudoer?).to eq false
      expect(user_7.read_attribute(:admin)).to eq true
    end

    it "sets admin independently of sudoer" do
      user_7.update_columns(admin: false, sudoer: true)

      patch :update, :params => { :id => 7, :user => { admin: '1', mail: "test7@example.net" } }

      user_7.reload
      expect(user_7.read_attribute(:admin)).to eq true
      expect(user_7.sudoer?).to eq true
    end

    it "clears admin independently of sudoer" do
      user_7.update_columns(admin: true, sudoer: true)

      patch :update, :params => { :id => 7, :user => { admin: '0', mail: "test7@example.net" } }

      user_7.reload
      expect(user_7.read_attribute(:admin)).to eq false
      expect(user_7.sudoer?).to eq true
    end

    it "leaves sudoer untouched when omitted from params" do
      user_7.update_columns(admin: false, sudoer: true)

      patch :update, :params => { :id => 7, :user => { mail: "test7@example.net" } }

      expect(user_7.reload.sudoer?).to eq true
    end
  end

  describe "GET edit" do
    it "renders an independent sudoer checkbox alongside the admin checkbox" do
      get :edit, :params => { :id => 7 }

      expect(response.body).to include('id="user_admin"')
      expect(response.body).to include('id="user_sudoer"')
    end
  end

end
