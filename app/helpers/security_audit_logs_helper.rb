# frozen_string_literal: true

module SecurityAuditLogsHelper
  def link_to_user_by_id_or_login(log)
    user = User.find_by(id: log.user_id)
    if user
      link_to(user.name, user_path(user))
    else
      h(log.user_login)
    end
  end

  def link_to_entity_or_text(log)
    return h(log.entity_name) if log.entity_type.blank? || log.entity_id.blank?

    case log.entity_type
    when 'User'
      user = User.find_by(id: log.entity_id)
      user ? link_to(h(log.entity_name), user_path(user)) : h(log.entity_name)
    when 'Project'
      project = Project.find_by(id: log.entity_id)
      project ? link_to(h(log.entity_name), settings_project_path(project)) : h(log.entity_name)
    when 'Role'
      role = Role.find_by(id: log.entity_id)
      role ? link_to(h(log.entity_name), edit_role_path(role)) : h(log.entity_name)
    when 'Group'
      group = Group.find_by(id: log.entity_id)
      group ? link_to(h(log.entity_name), edit_group_path(group)) : h(log.entity_name)
    when 'Member'
      h(log.entity_name)
    else
      h(log.entity_name)
    end
  end
end
