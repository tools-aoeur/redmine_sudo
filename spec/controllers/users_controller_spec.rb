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
    User.find(1).update_columns(sudoer: true) # ensure admin? returns true
  end

  describe "POST update" do
    it "gives both admin and sudoer when selecting admin in user form" do
      user_7.update_columns(admin: false, sudoer: false)
      user_7.reload
      expect(user_7.read_attribute(:admin)).to eq false
      expect(user_7.sudoer?).to eq false

      patch :update, :params => { :id => 7, :user => { admin: '1', mail: "test7@example.net" } }

      user_7.reload
      expect(user_7.read_attribute(:admin)).to eq true
      expect(user_7.sudoer?).to eq true
    end

    it "removes both admin and sudoer when deselecting admin in user form" do
      user_7.update_columns(admin: true, sudoer: true)
      user_7.reload
      expect(user_7.read_attribute(:admin)).to eq true
      expect(user_7.sudoer?).to eq true

      patch :update, :params => { :id => 7, :user => { admin: '0', mail: "test7@example.net" } }

      user_7.reload
      expect(user_7.read_attribute(:admin)).to eq false
      expect(user_7.sudoer?).to eq false
    end

    it "removes both admin and sudoer even when user is not currently sudoed" do
      user_7.update_columns(admin: true, sudoer: false)
      user_7.reload
      expect(user_7.read_attribute(:admin)).to eq true
      expect(user_7.sudoer?).to eq false

      patch :update, :params => { :id => 7, :user => { admin: '0', mail: "test7@example.net" } }

      user_7.reload
      expect(user_7.read_attribute(:admin)).to eq false
      expect(user_7.sudoer?).to eq false
    end
  end

end
