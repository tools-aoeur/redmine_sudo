# frozen_string_literal: true

# Patches the SudoController to audit sudo toggle events.
module RedmineSudo
  module Audit
    module SudoControllerPatch
      def toggle
        # Elevation is session state, so compare the session -- reloading the
        # user would only ever report the (unchanged) `admin` column.
        was_admin = sudo_admin_session_active?
        super
        now_admin = sudo_admin_session_active?
        if was_admin != now_admin
          action = now_admin ? 'sudo_activated' : 'sudo_deactivated'
          SecurityAuditLog.log(
            action: action,
            entity: ::User.current,
            entity_name: ::User.current.login,
            remote_ip: request.remote_ip
          )
        end
      end
    end
  end
end
