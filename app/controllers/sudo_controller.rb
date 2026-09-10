class SudoController < ApplicationController
  def toggle
    require_login # should render a 403 if no user found
    # A user with the `admin` column set is permanently admin and has nothing
    # to toggle; everyone else needs the sudoer permission.
    return render_403 unless User.current.can_become_admin?

    # Must run *before* `require_sudo_mode`: core renders the password form with
    # the current params as hidden fields, which is the only way back_url
    # survives the password re-entry round trip.
    set_back_url_from_referer

    if sudo_admin_session_active?
      drop_sudo_admin!
    else
      return unless require_sudo_mode # shows core's password reconfirmation form if needed

      elevate_sudo_admin!
    end

    redirect_back_or_default controller: "my", action: "page"
  end

  private

  # `redirect_back_or_default` issues a GET redirect to `back_url`. When core's
  # sudo-mode password form is resubmitted, the browser's referer is this very
  # POST-only action (the form posts back to itself) -- using it as back_url
  # would redirect to a GET on a POST-only route and raise a routing error.
  def set_back_url_from_referer
    return if params[:back_url].present? # round-tripped through the password form
    return if request.referer.blank?

    referer_path = URI.parse(request.referer).path rescue nil
    return if referer_path == sudo_toggle_path

    params[:back_url] = request.referer
  end
end
