require 'spec_helper'

# Regression test for the interaction between redmine_sudo and Redmine core
# workflow field permissions.
#
# `admin` (native Redmine column) means "permanently an administrator";
# `sudoer` is the permission to elevate to admin for the lifetime of one
# browser session.
# Core's Issue#roles_for_workflow uses `admin?`, which this plugin overrides to
# account for the session elevation, so a sudoer who has not elevated is
# treated as a normal user for read-only/required field rules.
describe 'Issue workflow field permissions with redmine_sudo', type: :model do
  fixtures :users, :roles, :projects, :trackers, :issue_statuses,
           :enumerations, :members, :member_roles

  let(:admin)   { User.find(1) }
  let(:project) { Project.find(1) }
  let(:role)    { Role.find(1) } # Manager, considers workflow
  let(:tracker) { Tracker.find(1) }
  let(:status)  { IssueStatus.find(1) }

  before do
    # The admin is a member of the project through a single role...
    Member.create!(user: admin, project: project, roles: [role])
    # ...and that role makes `due_date` read-only in the workflow.
    WorkflowPermission.create!(
      tracker_id: tracker.id, old_status_id: status.id,
      role_id: role.id, field_name: 'due_date', rule: 'readonly'
    )
    admin.update_columns(admin: false, sudoer: true)
  end

  def issue
    Issue.new(project: project, tracker: tracker, status: status,
              author: admin, subject: 'Test')
  end

  it 'enforces role-based workflow field permissions for a sudoer who has not elevated' do
    expect(admin.admin?).to eq false

    expect(issue.read_only_attribute_names(admin)).to include('due_date')
  end

  it 'ignores role-based workflow field permissions while elevated in the session' do
    admin.sudo_session_admin = true
    expect(admin.admin?).to eq true

    expect(issue.read_only_attribute_names(admin)).not_to include('due_date')
  end

  it 'ignores role-based workflow field permissions for the admin column' do
    admin.update_columns(admin: true, sudoer: false)
    expect(admin.admin?).to eq true

    expect(issue.read_only_attribute_names(admin)).not_to include('due_date')
  end
end
