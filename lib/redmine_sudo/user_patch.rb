# frozen_string_literal: true

module RedmineSudo::UserPatch
  # Toggles the admin (active) flag without triggering callbacks — this
  # deliberately bypasses `deliver_security_notification` so becoming/dropping
  # admin doesn't spam other admins on every toggle.
  def update_admin!(value)
    ::User.where(id: self.id).update_all(admin: value, updated_on: Time.now)
  end
end

