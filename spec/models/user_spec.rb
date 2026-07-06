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

  it 'should keep sudoer unchanged when toggling admin via update_admin!' do
    user = User.generate(admin: true)
    user.update_admin!(false)
    user.reload
    expect(user.sudoer?).to eq true
    expect(user.read_attribute(:admin)).to eq false
  end

  it 'admin? should return the raw admin column (toggled state)' do
    user = User.generate(admin: true)
    expect(user.admin?).to eq true

    user.update_admin!(false)
    user.reload
    expect(user.admin?).to eq false

    user.update_admin!(true)
    user.reload
    expect(user.admin?).to eq true
  end

  it 'sudoer? should stay true after admin is toggled off' do
    user = User.generate(admin: true)
    user.update_admin!(false)
    user.reload
    expect(user.sudoer?).to eq true
    expect(user.admin?).to eq false
  end

  it 'should not change admin on unrelated attribute updates' do
    user = User.generate(admin: true)
    user.update_admin!(false)
    user.reload
    expect(user.admin?).to eq false
    # unrelated update should not re-sync admin
    user.update_attribute(:firstname, 'John')
    expect(user.reload.admin?).to eq false
  end

  it 'should grant sudoer when admin is granted via save, but not clear it on revoke' do
    user = User.generate(admin: false)
    expect(user.sudoer?).to eq false

    # grant admin -> sudoer should be granted alongside it
    user.update_attribute(:admin, true)
    expect(user.reload.sudoer?).to eq true

    # revoke admin -> sudoer is deliberately left alone by this callback
    # (explicit revocation is handled by UsersControllerPatch instead)
    user.update_attribute(:admin, false)
    expect(user.reload.sudoer?).to eq true
  end

  it 'should #update_admin! sets a new updated_on date' do
    user = User.generate(admin: true)
    user.update_attribute(:updated_on, nil)
    expect(user.reload.updated_on).to eq nil
    user.update_admin!(false)
    refute_nil user.reload.updated_on
  end

  describe UserQuery do
    it 'shows the sudoer column by default, next to admin' do
      names = described_class.new.default_columns_names
      admin_index = names.index(:admin)
      expect(admin_index).not_to be_nil
      expect(names[admin_index + 1]).to eq :sudoer
    end

    it 'keeps the admin column as a plain boolean (no tri-state override)' do
      column = described_class.new.available_columns.find { |c| c.name == :admin }
      expect(column.class).to eq QueryColumn
    end
  end
end
