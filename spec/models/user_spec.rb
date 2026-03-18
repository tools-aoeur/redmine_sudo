require 'spec_helper'

# redmine 2.x doesn't use object_daddy anymore
unless User.respond_to?(:generate)
  def User.generate(attributes = {})
    @generated_user_login ||= 'user0'
    @generated_user_login.succ!
    user = User.new(attributes)
    user.login = @generated_user_login if user.login.blank?
    user.mail = "#{@generated_user_login}@example.com" if user.mail.blank?
    user.firstname = 'Bob' if user.firstname.blank?
    user.lastname = 'Doe' if user.lastname.blank?
    yield user if block_given?
    user.admin = true if attributes[:admin]
    user.save!
    user
  end
end

describe 'User' do
  it 'should set sudoer=true when creating an admin user' do
    user = User.generate(admin: true)
    expect(user.sudoer?).to eq true
    expect(user.read_attribute(:admin)).to eq true
  end

  it 'should set sudoer=false when creating a non-admin user' do
    user = User.generate(admin: false)
    expect(user.sudoer?).to eq false
    expect(user.read_attribute(:admin)).to eq false
  end

  it 'should keep admin unchanged when toggling sudoer via update_sudoer!' do
    user = User.generate(admin: true)
    user.update_sudoer!(false)
    user.reload
    expect(user.read_attribute(:admin)).to eq true
    expect(user.sudoer?).to eq false
  end

  it 'admin? should return the sudoer value (toggled state)' do
    user = User.generate(admin: true)
    expect(user.admin?).to eq true

    user.update_sudoer!(false)
    user.reload
    expect(user.admin?).to eq false

    user.update_sudoer!(true)
    user.reload
    expect(user.admin?).to eq true
  end

  it 'permanent_admin? should return the raw admin column' do
    user = User.generate(admin: true)
    user.update_sudoer!(false)
    user.reload
    expect(user.permanent_admin?).to eq true
    expect(user.admin?).to eq false
  end

  it 'should not change sudoer on unrelated attribute updates' do
    user = User.generate(admin: true)
    user.update_sudoer!(false)
    user.reload
    expect(user.sudoer?).to eq false
    # unrelated update should not re-sync sudoer
    user.update_attribute(:firstname, 'John')
    expect(user.reload.sudoer?).to eq false
  end

  it 'should sync sudoer when admin flag is changed via save' do
    user = User.generate(admin: true)
    # revoke admin → sudoer should be cleared
    user.update_attribute(:admin, false)
    expect(user.reload.sudoer?).to eq false
    # grant admin → sudoer should be set
    user.update_attribute(:admin, true)
    expect(user.reload.sudoer?).to eq true
  end

  it 'should #update_sudoer! sets a new updated_on date' do
    user = User.generate(admin: true)
    user.update_attribute(:updated_on, nil)
    expect(user.reload.updated_on).to eq nil
    user.update_sudoer!(false)
    refute_nil user.reload.updated_on
  end
end
