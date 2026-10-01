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
  it 'admin and sudoer are independent columns when creating an admin user' do
    user = User.generate(admin: true)
    expect(user.read_attribute(:admin)).to eq true
    expect(user.sudoer?).to eq false
  end

  it 'should set sudoer=false when creating a non-admin user' do
    user = User.generate(admin: false)
    expect(user.sudoer?).to eq false
    expect(user.read_attribute(:admin)).to eq false
  end

  it 'setting admin via save does not grant or affect sudoer' do
    user = User.generate(admin: false)
    expect(user.sudoer?).to eq false

    user.update_attribute(:admin, true)
    expect(user.reload.sudoer?).to eq false

    user.update_attribute(:admin, false)
    expect(user.reload.sudoer?).to eq false
  end

  it 'setting sudoer via save does not grant or affect admin' do
    user = User.generate(admin: false)
    expect(user.read_attribute(:admin)).to eq false

    user.update_attribute(:sudoer, true)
    expect(user.reload.read_attribute(:admin)).to eq false

    user.update_attribute(:sudoer, false)
    expect(user.reload.read_attribute(:admin)).to eq false
  end

  it 'should keep sudoer unchanged when elevating in a session' do
    user = User.generate(admin: false)
    user.update_attribute(:sudoer, true)

    user.sudo_session_admin = true # simulates "Become Admin"
    expect(user.admin?).to eq true
    user.sudo_session_admin = false
    expect(user.admin?).to eq false

    user.reload
    expect(user.sudoer?).to eq true
    expect(user.read_attribute(:admin)).to eq false
  end

  it 'admin? is true for the admin column regardless of any session state' do
    user = User.generate(admin: true)
    expect(user.admin?).to eq true

    user.sudo_session_admin = false
    expect(user.admin?).to eq true
  end

  it 'admin? ignores the session elevation for OAuth-authorized requests' do
    user = User.generate(admin: false)
    user.update_attribute(:sudoer, true)
    user.sudo_session_admin = true
    expect(user.admin?).to eq true

    user.oauth_scope = ['view_project']
    expect(user.admin?).to eq false
  end

  it 'admin? is false for a sudoer that never elevated' do
    user = User.generate(admin: false)
    user.update_attribute(:sudoer, true)
    expect(user.admin?).to eq false
  end

  describe '#can_become_admin?' do
    it 'is true for a plain sudoer' do
      user = User.generate(admin: false)
      user.update_attribute(:sudoer, true)
      expect(user.can_become_admin?).to eq true
    end

    it 'stays true while elevated, so the Become User toggle keeps showing' do
      user = User.generate(admin: false)
      user.update_attribute(:sudoer, true)
      user.sudo_session_admin = true
      expect(user.can_become_admin?).to eq true
    end

    it 'is false when the admin column is already set, leaving nothing to elevate' do
      user = User.generate(admin: true)
      expect(user.can_become_admin?).to eq false
    end

    it 'is false for a plain user' do
      expect(User.generate(admin: false).can_become_admin?).to eq false
    end
  end

  describe '#safe_attribute_names' do
    let(:target) { User.generate(admin: false) }

    it 'lets an admin grant admin to somebody else' do
      expect(target.safe_attribute_names(User.generate(admin: true))).to include('admin')
    end

    it 'refuses to let an admin change their own admin flag' do
      admin = User.generate(admin: true)
      expect(admin.safe_attribute_names(admin)).not_to include('admin')
    end

    it 'refuses to let an elevated sudoer grant admin to anybody' do
      sudoer = User.generate(admin: false)
      sudoer.update_attribute(:sudoer, true)
      sudoer.sudo_session_admin = true

      expect(target.safe_attribute_names(sudoer)).not_to include('admin')
      expect(sudoer.safe_attribute_names(sudoer)).not_to include('admin')
    end
  end

  describe '#must_activate_twofa?' do
    before { Setting.twofa = '3' } # required for administrators
    after { Setting.twofa = '0' }

    it 'covers sudoers, who can reach admin at will' do
      user = User.generate(admin: false)
      user.update_attribute(:sudoer, true)
      expect(user.must_activate_twofa?).to eq true
    end

    it 'still covers the admin column' do
      expect(User.generate(admin: true).must_activate_twofa?).to eq true
    end

    it 'leaves plain users alone' do
      expect(User.generate(admin: false).must_activate_twofa?).to be_falsey
    end
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
