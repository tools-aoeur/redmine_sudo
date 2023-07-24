Rails.autoloaders.main.ignore("#{__dir__}/lib") if Rails::VERSION::MAJOR >= 6

require_relative 'lib/redmine_sudo/hooks'

# Plugin generic informations
Redmine::Plugin.register :redmine_sudo do
  name 'Redmine Sudo plugin'
  description 'This plugin gives sudo-like powers to Redmine administrators'
  author 'Jean-Baptiste BARTH (orig)'
  author_url 'mailto:jeanbaptiste.barth@gmail.com'
  url 'https://github.com/tools-aoeur/redmine_sudo'
  version '2.0.0'
  requires_redmine version_or_higher: '5.0.0'
  requires_redmine_plugin :redmine_base_rspec, version_or_higher: '2.0.0' if Rails.env.test?
  settings default: {
    'become_admin' => '[sudo -v]',
    'become_user' => '[sudo -k]',
    'additional_css' => "#top-menu { background-color:#BA0C04; }\n
                        #header { background-color:#dd0037; }\n
                        #main-menu li a { background-color:#BA0C04; }\n
                        #main-menu li a.new-object { background-color:#BA0C04; }\n
                        #main-menu li a:hover { background-color:#8D0A02; }\n
                        @media all and (max-width: 899px) { #header{ background-color: #dd0037 !important; }" },
           partial: 'settings/redmine_sudo_settings'
end

# Patches to existing classes/modules
if Rails::VERSION::MAJOR < 6
  klass = defined?(ActiveSupport::Reloader) ? ActiveSupport::Reloader : ActionDispatch::Callbacks
  klass.to_prepare do
    require_relative 'lib/redmine_sudo/user_patch'
  end
else
  # see https://www.redmine.org/issues/36245#note-11 and following for changes with zeitwerk autoloading
  Rails.application.config.after_initialize do
    require_relative 'lib/redmine_sudo/user_patch'
  end
end
