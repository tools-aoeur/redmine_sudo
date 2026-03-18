require_dependency 'project' # see: http://www.redmine.org/issues/11035
require_dependency 'principal'
require_dependency 'user'

module RedmineSudo::UserPatch
  # Override admin? to reflect the toggled sudoer state.
  # All Redmine permission checks (allowed_to?, safe_attributes, API output)
  # will use this, so toggling sudoer on/off controls active admin privileges.
  def admin?
    self.sudoer?
  end

  # Returns the permanent admin flag from the DB column,
  # unaffected by the sudo toggle.
  def permanent_admin?
    read_attribute(:admin)
  end

  # Syncs sudoer to match admin when the admin flag is granted/revoked or on creation.
  def sync_sudoer
    if new_record? || admin_changed?
      self.sudoer = read_attribute(:admin)
    end
    true
  end

  # Toggles the sudoer (active admin) flag without triggering callbacks.
  def update_sudoer!(value)
    User.where(id: self.id).update_all(sudoer: value)
    User.where(id: self.id).update_all(updated_on: Time.now)
  end
end

class User < Principal
  prepend RedmineSudo::UserPatch
  before_save :sync_sudoer
end
