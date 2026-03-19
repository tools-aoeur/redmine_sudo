# frozen_string_literal: true

# Central loader for all security audit patches.
# Required from hooks.rb after plugins are loaded.

require_relative 'audit/sudo_controller_patch'
require_relative 'audit/users_controller_patch'
require_relative 'audit/projects_controller_patch'
require_relative 'audit/members_controller_patch'
require_relative 'audit/roles_controller_patch'
require_relative 'audit/groups_controller_patch'
require_relative 'audit/settings_controller_patch'
require_relative 'audit/auth_sources_controller_patch'

# Apply patches to Redmine controllers
SudoController.prepend RedmineSudo::SudoControllerAuditPatch

UsersController.include RedmineSudo::Audit::UsersControllerPatch
ProjectsController.include RedmineSudo::Audit::ProjectsControllerPatch
MembersController.include RedmineSudo::Audit::MembersControllerPatch
RolesController.include RedmineSudo::Audit::RolesControllerPatch
GroupsController.include RedmineSudo::Audit::GroupsControllerPatch
SettingsController.include RedmineSudo::Audit::SettingsControllerPatch
AuthSourcesController.include RedmineSudo::Audit::AuthSourcesControllerPatch
