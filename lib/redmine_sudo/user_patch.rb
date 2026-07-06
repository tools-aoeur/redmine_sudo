# frozen_string_literal: true

module RedmineSudo::UserPatch
  # Grants sudoer (permission to become admin) alongside admin on creation or
  # grant. Revocation of sudoer is a deliberate, explicit action handled by
  # UsersControllerPatch — this callback never clears it.
  def sync_sudoer
    if (new_record? || admin_changed?) && read_attribute(:admin)
      self.sudoer = true
    end
    true
  end

  # Toggles the admin (active) flag without triggering callbacks — this
  # deliberately bypasses `deliver_security_notification` so becoming/dropping
  # admin doesn't spam other admins on every toggle.
  def update_admin!(value)
    ::User.where(id: self.id).update_all(admin: value, updated_on: Time.now)
  end
end

