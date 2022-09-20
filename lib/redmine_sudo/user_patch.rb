require_dependency 'project' # see: http://www.redmine.org/issues/11035
require_dependency 'principal'
require_dependency 'user'

class User
  before_save :update_sudoer

  def update_sudoer
    self.sudoer = admin if new_record? || admin? || admin_changed?
    true
  end

  def update_admin!(value)
    User.where(id: id).update_all(admin: value)
    User.where(id: id).update_all(updated_on: Time.now)
  end
end
