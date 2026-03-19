# frozen_string_literal: true

# Patches the SudoController to audit sudo toggle events.
module RedmineSudo
  module SudoControllerAuditPatch
    def toggle
      was_admin = User.current.admin?
      super
      now_admin = User.current.reload.admin?
      if was_admin != now_admin
        action = now_admin ? 'sudo_activated' : 'sudo_deactivated'
        SecurityAuditLog.log(
          action: action,
          entity: User.current,
          entity_name: User.current.login,
          remote_ip: request.remote_ip
        )
      end
    end
  end
end
