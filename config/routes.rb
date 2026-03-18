RedmineApp::Application.routes.draw do
  post 'sudo/toggle', to: 'sudo#toggle', as: 'sudo_toggle'
end
