class SudoController < ApplicationController
  def toggle
    require_login # should render a 403 if no user found
    return render_403 unless User.current.sudoer?

    if User.current.read_attribute(:admin)
      drop_active_admin!
    else
      return unless require_sudo_mode # shows core's password reconfirmation form if needed

      User.current.update_admin!(true)
    end

    set_back_url_from_referer
    redirect_back_or_default controller: "my", action: "page"
  end

  private

  # `redirect_back_or_default` issues a GET redirect to `back_url`. When core's
  # sudo-mode password form is resubmitted, the browser's referer is this very
  # POST-only action (the form posts back to itself) -- using it as back_url
  # would redirect to a GET on a POST-only route and raise a routing error.
  def set_back_url_from_referer
    return if request.referer.blank?

    referer_path = URI.parse(request.referer).path rescue nil
    return if referer_path == sudo_toggle_path

    params[:back_url] = url_for(request.referer)
  end
end
