require 'spec_helper'

# Core mails "all administrators" -- `User.active.where(admin: true)` -- when
# someone gains or loses admin and when application settings change. Sudoers
# are the people who actually administer the instance, so both broadcasts have
# to reach them too.
describe 'Admin notification recipients', type: :model do
  def create_user(login, attributes = {})
    User.create!(
      { login: login, firstname: 'Bob', lastname: 'Doe',
        mail: "#{login}@example.com" }.merge(attributes)
    )
  end

  let!(:admin)  { create_user('permanent', admin: true) }
  let!(:sudoer) { create_user('sudo', sudoer: true) }
  let!(:plain)  { create_user('plain') }

  it 'prepends the Mailer patch' do
    expect(Mailer.singleton_class.ancestors).to include(RedmineSudo::MailerPatch)
  end

  it 'mails application setting changes to admins and sudoers alike' do
    notified = []
    allow(Mailer).to receive(:settings_updated) do |user, *|
      notified << user
      double(deliver_later: true)
    end

    Mailer.deliver_settings_updated(admin, [:host_name], remote_ip: '127.0.0.1')

    expect(notified).to include(admin, sudoer)
    expect(notified).not_to include(plain)
  end

  it 'widens security notifications only for the "an admin changed" broadcast' do
    notified = []
    allow(Mailer).to receive(:security_notification) do |user, *|
      notified << user
      double(deliver_later: true)
    end

    # A personal notice (your mail address changed, ...) keeps its recipient.
    Mailer.deliver_security_notification([admin], admin, remote_ip: '127.0.0.1')
    expect(notified).to eq [admin]

    notified.clear
    RedmineSudo::AdminNotification.broadcast do
      Mailer.deliver_security_notification([admin], admin, remote_ip: '127.0.0.1')
    end
    expect(notified).to include(admin, sudoer)
    expect(notified).not_to include(plain)
  end
end
