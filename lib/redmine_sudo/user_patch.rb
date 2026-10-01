# frozen_string_literal: true

module RedmineSudo::UserPatch
  # Set by RedmineSudo::ApplicationControllerPatch on the User instance built
  # for the current request, and only when that request was authenticated by
  # the session cookie of a user who elevated in that very session. Everything
  # else -- REST API keys, OAuth bearer tokens, atom keys, rake tasks,
  # background jobs -- leaves it nil and therefore sees the plain `admin`
  # column.
  attr_writer :sudo_session_admin

  # The `admin` column is permanent and privileged everywhere, including the
  # REST API. `sudoer` only allows elevating to admin for the lifetime of one
  # browser session, and that elevation never touches the database.
  def admin?
    return true if super

    @sudo_session_admin == true && !authorized_by_oauth?
  end

  # Eligible for the Become Admin action. A user with the `admin` column set is
  # already privileged and has nothing to elevate.
  def can_become_admin?
    logged? && sudoer? && !read_attribute(:admin)
  end

  # Core only forces 2FA on `admin?`, which is false for a sudoer at rest even
  # though that sudoer can reach admin at will.
  def must_activate_twofa?
    return false if twofa_active?

    super || (Setting.twofa_required_for_administrators? && sudoer?)
  end
end

