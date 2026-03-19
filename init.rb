# frozen_string_literal: true

require 'redmine'
require_relative 'lib/redmine_sudo/hooks'

Rails.autoloaders.main.ignore("#{__dir__}/lib")

# Plugin generic informations
Redmine::Plugin.register :redmine_sudo do
  name 'Redmine Sudo plugin'
  description 'This plugin gives sudo-like powers to Redmine administrators'
  author 'Jean-Baptiste BARTH (orig)'
  author_url 'mailto:jeanbaptiste.barth@gmail.com'
  url 'https://github.com/tools-aoeur/redmine_sudo'
  version '6.1.0'
  requires_redmine version_or_higher: '6.1.0'

  Redmine::MenuManager.map :account_menu do |menu|
    menu.push :sudo, :sudo_toggle_path,
              html: { method: 'post',
                      id: 'sudo_id' },
              caption: proc {
                Setting.plugin_redmine_sudo[User.current.admin? ? 'become_user' : 'become_admin']
              },
              before: :my_account,
              class: 'sudo',
              if: proc { User.current.permanent_admin? }
  end

  Redmine::MenuManager.map :admin_menu do |menu|
    menu.push :security_audit_log, :security_audit_logs_path,
              caption: :label_security_audit_log,
              icon: 'redmine_sudo',
              plugin: :redmine_sudo,
              html: { class: 'icon icon-redmine_sudo' },
              if: proc { User.current.admin? }
  end

  settings default: {
             'become_admin' => 'Become Admin',
             'become_user' => 'Become User'
           },
           partial: 'settings/redmine_sudo_settings'
end
