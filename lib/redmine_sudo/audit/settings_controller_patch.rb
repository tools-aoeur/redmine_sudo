# frozen_string_literal: true

# Patches SettingsController to audit system setting changes.
require_dependency 'settings_controller'

module RedmineSudo
  module Audit
    module SettingsControllerPatch
      extend ActiveSupport::Concern

      included do
        after_action :audit_settings_update, only: [:edit]
      end

      private

      def audit_settings_update
        return unless request.post? || request.patch? || request.put?

        SecurityAuditLog.log(
          action: 'settings_updated',
          details: "Tab: #{params[:tab].presence || 'general'}",
          remote_ip: request.remote_ip
        )
      end
    end
  end
end
