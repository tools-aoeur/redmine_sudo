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
              html: { method: 'get',
                      id: "sudo_id" },
              caption: proc {
                Setting.plugin_redmine_sudo[User.current.admin? ? "become_user" : "become_admin"]
              },
              before: :my_account,
              class: "sudo",
              if: proc { User.current.sudoer? }
  end

  settings default: {
             'become_admin' => '[sudo -v]',
    'become_user' => '[sudo -k]',
    'additional_css' => "#top-menu { background-color:#BA0C04; }\n
                        #header { background-color:#dd0037; }\n
                        #main-menu li a { background-color:#BA0C04; }\n
                        #main-menu li a.new-object { background-color:#BA0C04; }\n
                        #main-menu li a:hover { background-color:#8D0A02; }\n
                        @media all and (max-width: 899px) { #header{ background-color: #dd0037 !important; }"
           },
           partial: 'settings/redmine_sudo_settings'
end
