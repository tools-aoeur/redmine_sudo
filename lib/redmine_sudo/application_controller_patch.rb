# frozen_string_literal: true

# Manages Redmine core's own SudoMode session lifecycle for the active admin
# state: drops it once the session expires, and slides the session forward
# on any confirmed admin action so genuine ongoing work doesn't expire mid
# task.
module RedmineSudo
  module ApplicationControllerPatch
    extend ActiveSupport::Concern

    prepended do
      before_action :enforce_sudo_grace_timeout
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

    # Read-only check — `sudo_timestamp_valid?` is a plain comparison with no
    # side effects, unlike `Redmine::SudoMode.active?`/`.active!` which mark
    # the session as "used" and cause it to be silently refreshed. This keeps
    # ordinary browsing from extending the window; only genuine admin actions
    # (via `require_admin` above, core's own `require_sudo_mode`, or our own
    # Become Admin) do that.
    def enforce_sudo_grace_timeout
      return if api_request?
      return unless User.current.logged? && User.current.read_attribute(:admin)
      return unless Redmine::SudoMode.enabled?
      return if sudo_timestamp_valid?

      drop_active_admin!
      SecurityAuditLog.log(
        action: 'sudo_expired',
        entity: User.current,
        entity_name: User.current.login,
        remote_ip: request.remote_ip
      )
    end

    # Drops the active admin flag and forces the core sudo session to be
    # considered expired, so the next sudo-gated action (including our own
    # Become Admin) requires a fresh password re-entry.
    def drop_active_admin!
      User.current.update_admin!(false)
      session[:sudo_timestamp] = 0
    end
  end
end

