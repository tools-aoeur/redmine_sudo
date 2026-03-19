RedmineApp::Application.routes.draw do
  post 'sudo/toggle', to: 'sudo#toggle', as: 'sudo_toggle'
  resources :security_audit_logs, only: [:index]
end
