# frozen_string_literal: true

# Patches AuthSourcesController to audit authentication source changes (LDAP, etc.).
require_dependency 'auth_sources_controller'

module RedmineSudo
  module Audit
    module AuthSourcesControllerPatch
      extend ActiveSupport::Concern

      included do
        after_action :audit_auth_source_create, only: [:create]
        after_action :audit_auth_source_update, only: [:update]
        after_action :audit_auth_source_destroy, only: [:destroy]
      end

      private

      def audit_auth_source_create
        return unless @auth_source.present? && @auth_source.persisted? && @auth_source.errors.empty?

        SecurityAuditLog.log(
          action: 'auth_source_created',
          entity: @auth_source,
          details: "Type: #{@auth_source.type}",
          remote_ip: request.remote_ip
        )
      end

      def audit_auth_source_update
        return unless @auth_source.present? && @auth_source.errors.empty?

        SecurityAuditLog.log(
          action: 'auth_source_updated',
          entity: @auth_source,
          remote_ip: request.remote_ip
        )
      end

      def audit_auth_source_destroy
        return unless @auth_source.present?

        SecurityAuditLog.log(
          action: 'auth_source_deleted',
          details: "Name: #{@auth_source.name}",
          remote_ip: request.remote_ip
        )
      end
    end
  end
end
