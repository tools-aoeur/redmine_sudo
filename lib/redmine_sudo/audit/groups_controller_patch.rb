# frozen_string_literal: true

# Patches GroupsController to audit group CRUD and membership changes.
require_dependency 'groups_controller'

module RedmineSudo
  module Audit
    module GroupsControllerPatch
      extend ActiveSupport::Concern

      included do
        after_action :audit_group_create, only: [:create]
        after_action :audit_group_update, only: [:update]
        after_action :audit_group_destroy, only: [:destroy]
        after_action :audit_group_add_users, only: [:add_users]
        after_action :audit_group_remove_user, only: [:remove_user]
      end

      private

      def audit_group_create
        return unless @group.present? && @group.persisted? && @group.errors.empty?

        SecurityAuditLog.log(
          action: 'group_created',
          entity: @group,
          remote_ip: request.remote_ip
        )
      end

      def audit_group_update
        return unless @group.present? && @group.errors.empty?

        changes = @group.saved_changes.except(:updated_on)
        return if changes.empty?

        detail_parts = changes.map { |key, (from, to)| "#{key}: #{from} -> #{to}" }

        SecurityAuditLog.log(
          action: 'group_updated',
          entity: @group,
          details: detail_parts.join(', '),
          remote_ip: request.remote_ip
        )
      end

      def audit_group_destroy
        return unless @group.present?

        SecurityAuditLog.log(
          action: 'group_deleted',
          entity_type: 'Group',
          details: "Name: #{@group.name}",
          remote_ip: request.remote_ip
        )
      end

      def audit_group_add_users
        return unless @group.present?

        user_ids = params[:user_ids] || params[:user_id]
        users = User.where(id: Array(user_ids))
        users.each do |user|
          SecurityAuditLog.log(
            action: 'group_user_added',
            entity: @group,
            details: "User: #{user.login} (#{user.name})",
            remote_ip: request.remote_ip
          )
        end
      end

      def audit_group_remove_user
        return unless @group.present?

        user = User.find_by(id: params[:user_id])
        SecurityAuditLog.log(
          action: 'group_user_removed',
          entity: @group,
          details: "User: #{user&.login} (#{user&.name})",
          remote_ip: request.remote_ip
        )
      end
    end
  end
end
