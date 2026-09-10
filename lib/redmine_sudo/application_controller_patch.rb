# frozen_string_literal: true

# Elevated admin rights live in the browser session and nowhere else. Nothing
# in here ever writes the `admin` column, so one session can neither elevate
# nor demote another, and any request that carries no session -- REST API,
# OAuth, atom key, rake task, background job -- always runs with the user's
# plain, unelevated rights.
#
# This module also manages Redmine core's own SudoMode session lifecycle for
# the elevated state: it drops the elevation once that session expires, and
# slides the session forward on any confirmed admin action so genuine ongoing
# work doesn't expire mid task.
module RedmineSudo
  module ApplicationControllerPatch
    extend ActiveSupport::Concern

    # Holds the id of the user who elevated in this session. Storing the id
    # rather than a boolean means the key can never elevate a different user
    # if the session outlives a re-login.
    SUDO_ADMIN_SESSION_KEY = :sudo_admin_user_id

    prepended do
      before_action :enforce_sudo_grace_timeout
    end

    # Marks the request's own User instance as elevated. Only an interactive
    # session login reaches this: `session[:user_id]` is set by the login form
    # alone, and core's `find_current_user` ignores the session entirely for
    # `.json`/`.xml` API requests.
    def find_current_user
      user = super
      user.sudo_session_admin = true if user && sudo_admin_elevated?(user)
      user
    end

    # Slides Redmine core's SudoMode session on any `require_admin`-gated
    # action, not just the handful of controllers (Users, Roles, Settings,
    # Groups, ...) that core itself additionally wraps in `require_sudo_mode`.
    #
    # Without this, working continuously in an "auxiliary" admin screen that
    # is only gated by `require_admin` (Trackers, IssueStatuses, Enumerations,
    # CustomFields, Workflows, ...) never touches `Redmine::SudoMode.active?`,
    # so the sudo timestamp goes stale after `sudo_mode_timeout` minutes and
    # `enforce_sudo_grace_timeout` below auto-drops admin mid-task even though
    # the user never stopped working.
    #
    # `Redmine::SudoMode.active?` only reads the current session state and
    # marks it "used" as a side effect (see
    # Redmine::SudoMode::Controller#sudo_mode around_action) — unlike
    # `require_sudo_mode`, it never itself demands a password. So calling it
    # here can only slide an already-valid session forward; it can never
    # force a re-prompt for actions that didn't require one before.
    def require_admin
      result = super
      Redmine::SudoMode.active? if result
      result
    end

    private

    # True when this request may act on the elevation stored in this session.
    #
    # The first two checks together mirror exactly the branch of core's
    # `find_current_user` that authenticates from the session, so an API key,
    # atom key or OAuth token can never inherit an elevation even when the
    # client also happens to send the session cookie (a browser calling
    # `/users.json?key=...` does).
    def sudo_admin_elevated?(user)
      return false if api_request?
      return false unless session[:user_id] == user.id
      return false unless session[SUDO_ADMIN_SESSION_KEY] == user.id
      # redmine_pretend impersonation: the impersonated user must never
      # inherit the impersonator's elevation.
      return false if session[:real_user_id].present?
      # With core sudo mode disabled there is no window to expire against, so
      # the elevation simply lasts for the whole session.
      return true unless Redmine::SudoMode.enabled?

      sudo_timestamp_valid?
    end

    def sudo_admin_session_active?
      session[SUDO_ADMIN_SESSION_KEY].present?
    end

    def elevate_sudo_admin!
      session[SUDO_ADMIN_SESSION_KEY] = User.current.id
      User.current.sudo_session_admin = true
    end

    # Drops the elevation and forces the core sudo session to be considered
    # expired, so the next sudo-gated action (including a future Become Admin)
    # requires a fresh password re-entry.
    def drop_sudo_admin!
      session.delete(SUDO_ADMIN_SESSION_KEY)
      session[:sudo_timestamp] = 0
      User.current.sudo_session_admin = false
    end

    # Read-only check — `sudo_timestamp_valid?` is a plain comparison with no
    # side effects, unlike `Redmine::SudoMode.active?`/`.active!` which mark
    # the session as "used" and cause it to be silently refreshed. This keeps
    # ordinary browsing from extending the window; only genuine admin actions
    # (via `require_admin` above, core's own `require_sudo_mode`, or our own
    # Become Admin) do that.
    #
    # `find_current_user` has already refused to elevate by the time this
    # runs, so all that is left here is clearing the stale session key and
    # recording the expiry.
    def enforce_sudo_grace_timeout
      return unless sudo_admin_session_active?
      return unless Redmine::SudoMode.enabled?
      return if sudo_timestamp_valid?

      user = User.current
      drop_sudo_admin!
      SecurityAuditLog.log(
        action: 'sudo_expired',
        entity: user,
        entity_name: user.login,
        remote_ip: request.remote_ip
      )
    end
  end
end

