# frozen_string_literal: true

module RedmineSudo
  class Hooks < Redmine::Hook::ViewListener
    render_on :view_layouts_base_html_head, partial: 'sudo/sudo_styles'
    render_on :view_users_form, partial: 'sudo/sudo_user_form'
  end
end
