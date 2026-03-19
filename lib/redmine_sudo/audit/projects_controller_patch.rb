# frozen_string_literal: true

# Patches ProjectsController to audit project creation, updates, and archival.
require_dependency 'projects_controller'

module RedmineSudo
  module Audit
    module ProjectsControllerPatch
      extend ActiveSupport::Concern

      included do
        after_action :audit_project_create, only: [:create]
        after_action :audit_project_update, only: [:update]
        after_action :audit_project_destroy, only: [:destroy]
        after_action :audit_project_archive, only: [:archive]
        after_action :audit_project_unarchive, only: [:unarchive]
        after_action :audit_project_close, only: [:close]
        after_action :audit_project_reopen, only: [:reopen]
      end

      private

      def audit_project_create
        return unless @project.present? && @project.persisted? && @project.errors.empty?

        SecurityAuditLog.log(
          action: 'project_created',
          entity: @project,
          details: "Identifier: #{@project.identifier}, Public: #{@project.is_public?}",
          remote_ip: request.remote_ip
        )
      end

      def audit_project_update
        return unless @project.present? && @project.errors.empty?

        changes = @project.saved_changes.except(:updated_on)
        return if changes.empty?

        detail_parts = changes.map do |key, (from, to)|
          "#{key}: #{from} -> #{to}"
        end

        SecurityAuditLog.log(
          action: 'project_updated',
          entity: @project,
          details: detail_parts.join(', '),
          remote_ip: request.remote_ip
        )
      end

      def audit_project_destroy
        return unless @project.present?

        SecurityAuditLog.log(
          action: 'project_deleted',
          entity_type: 'Project',
          details: "Name: #{@project.name}, Identifier: #{@project.identifier}",
          remote_ip: request.remote_ip
        )
      end

      def audit_project_archive
        return unless @project.present?

        SecurityAuditLog.log(
          action: 'project_archived',
          entity: @project,
          remote_ip: request.remote_ip
        )
      end

      def audit_project_unarchive
        return unless @project.present?

        SecurityAuditLog.log(
          action: 'project_unarchived',
          entity: @project,
          remote_ip: request.remote_ip
        )
      end

      def audit_project_close
        return unless @project.present?

        SecurityAuditLog.log(
          action: 'project_closed',
          entity: @project,
          remote_ip: request.remote_ip
        )
      end

      def audit_project_reopen
        return unless @project.present?

        SecurityAuditLog.log(
          action: 'project_reopened',
          entity: @project,
          remote_ip: request.remote_ip
        )
      end
    end
  end
end
