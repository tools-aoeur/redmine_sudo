# frozen_string_literal: true

# Patches MembersController to audit membership changes.
module RedmineSudo
  module Audit
    module MembersControllerPatch
      extend ActiveSupport::Concern

      included do
        after_action :audit_member_create, only: [:create]
        after_action :audit_member_update, only: [:update]
        after_action :audit_member_destroy, only: [:destroy]
      end

      private

      def audit_member_create
        return unless @members.present?

        Array(@members).each do |member|
          next unless member.persisted? && member.errors.empty?

          principal = member.principal
          roles = member.roles.map(&:name).join(', ')
          SecurityAuditLog.log(
            action: 'member_added',
            entity: member,
            entity_name: "#{principal&.name} in #{member.project&.name}",
            details: "Roles: #{roles}",
            remote_ip: request.remote_ip
          )
        end
      end

      def audit_member_update
        return unless @member.present? && @member.errors.empty?

        principal = @member.principal
        roles = @member.roles.map(&:name).join(', ')
        SecurityAuditLog.log(
          action: 'member_updated',
          entity: @member,
          entity_name: "#{principal&.name} in #{@member.project&.name}",
          details: "Roles: #{roles}",
          remote_ip: request.remote_ip
        )
      end

      def audit_member_destroy
        return unless @member.present?

        principal = @member.principal
        SecurityAuditLog.log(
          action: 'member_removed',
          entity_type: 'Member',
          entity_name: "#{principal&.name} in #{@member.project&.name}",
          remote_ip: request.remote_ip
        )
      end
    end
  end
end
