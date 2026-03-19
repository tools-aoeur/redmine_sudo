# frozen_string_literal: true

# Patches RolesController to audit role CRUD and permission changes.
require_dependency 'roles_controller'

module RedmineSudo
  module Audit
    module RolesControllerPatch
      extend ActiveSupport::Concern

      included do
        after_action :audit_role_create, only: [:create]
        after_action :audit_role_update, only: [:update]
        after_action :audit_role_destroy, only: [:destroy]
        after_action :audit_permissions_update, only: [:permissions]
      end

      private

      def audit_role_create
        return unless @role.present? && @role.persisted? && @role.errors.empty?

        SecurityAuditLog.log(
          action: 'role_created',
          entity: @role,
          details: "Permissions: #{@role.permissions&.join(', ')}",
          remote_ip: request.remote_ip
        )
      end

      def audit_role_update
        return unless @role.present? && @role.errors.empty?

        changes = @role.saved_changes.except(:updated_on)
        return if changes.empty?

        detail_parts = changes.map do |key, (from, to)|
          if key == 'permissions'
            added = (Array(to) - Array(from)).map(&:to_s)
            removed = (Array(from) - Array(to)).map(&:to_s)
            parts = []
            parts << "Added: #{added.join(', ')}" if added.any?
            parts << "Removed: #{removed.join(', ')}" if removed.any?
            "Permissions #{parts.join('; ')}"
          else
            "#{key}: #{from} -> #{to}"
          end
        end

        SecurityAuditLog.log(
          action: 'role_updated',
          entity: @role,
          details: detail_parts.join(', '),
          remote_ip: request.remote_ip
        )
      end

      def audit_role_destroy
        return unless @role.present?

        SecurityAuditLog.log(
          action: 'role_deleted',
          entity_type: 'Role',
          details: "Name: #{@role.name}",
          remote_ip: request.remote_ip
        )
      end

      def audit_permissions_update
        return unless request.post?

        SecurityAuditLog.log(
          action: 'permissions_updated',
          details: 'Bulk permissions update via roles/permissions',
          remote_ip: request.remote_ip
        )
      end
    end
  end
end
