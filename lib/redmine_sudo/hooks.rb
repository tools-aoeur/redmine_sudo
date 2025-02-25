module RedmineSudo
  class Hooks < Redmine::Hook::ViewListener
    render_on :view_layouts_base_html_head, partial: 'sudo/sudo_styles'
    render_on :view_layouts_base_top_menu, partial: 'sudo/sudo_link'
  end
end
