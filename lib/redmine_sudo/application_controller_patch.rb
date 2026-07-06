# frozen_string_literal: true

# Auto-drops the active admin state once Redmine core's own SudoMode session
# has expired, and provides the shared helper both the manual toggle and this
# automatic path use to drop admin consistently.
module RedmineSudo
  module ApplicationControllerPatch
    extend ActiveSupport::Concern

    included do
      before_action :enforce_sudo_grace_timeout
    end

    private

    # Read-only check — `sudo_timestamp_valid?` is a plain comparison with no
    # side effects, unlike `Redmine::SudoMode.active?`/`.active!` which mark
    # the session as "used" and cause it to be silently refreshed. This keeps
    # ordinary browsing from extending the window; only genuine core
    # `require_sudo_mode`-gated actions (and our own Become Admin) do that.
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
