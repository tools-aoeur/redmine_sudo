# frozen_string_literal: true

# Patches UsersController to audit user CRUD, locking, and admin changes.
module RedmineSudo
  module Audit
    module UsersControllerPatch
      extend ActiveSupport::Concern

      included do
        after_action :audit_user_create, only: [:create]
        after_action :audit_user_update, only: [:update]
        after_action :audit_user_destroy, only: [:destroy]
      end

      private

      def audit_user_create
        return unless @user.present? && @user.persisted? && @user.errors.empty?

        SecurityAuditLog.log(
          action: 'user_created',
          entity: @user,
          entity_name: @user.login,
          details: "Status: #{@user.status}, Admin: #{@user.sudoer?}",
          remote_ip: request.remote_ip
        )
      end

      def audit_user_update
        return unless @user.present? && @user.errors.empty?

        changes = @user.saved_changes.except(:updated_on, :hashed_password, :salt)
        return if changes.empty?

        detail_parts = []

        if changes.key?('admin')
          from, to = changes['admin']
          detail_parts << "Admin: #{from} -> #{to}"
        end

        if changes.key?('status')
          from, to = changes['status']
          detail_parts << "Status: #{status_label(from)} -> #{status_label(to)}"
        end

        if changes.key?('login')
          from, to = changes['login']
          detail_parts << "Login: #{from} -> #{to}"
        end

        if changes.key?('mail')
          from, to = changes['mail']
          detail_parts << "Mail: #{from} -> #{to}"
        end

        if changes.key?('sudoer')
          from, to = changes['sudoer']
          detail_parts << "Active Admin: #{from} -> #{to}"
        end

        # Log remaining changes generically
        logged_keys = %w[admin status login mail sudoer]
        (changes.keys - logged_keys).each do |key|
          from, to = changes[key]
          detail_parts << "#{key}: #{from} -> #{to}"
        end

        return if detail_parts.empty?

        SecurityAuditLog.log(
          action: 'user_updated',
          entity: @user,
          entity_name: @user.login,
          details: detail_parts.join(', '),
          remote_ip: request.remote_ip
        )
      end

      def audit_user_destroy
        return unless @user.present?

        SecurityAuditLog.log(
          action: 'user_deleted',
          entity_type: 'User',
          details: "Login: #{@user.login}, Name: #{@user.name}",
          remote_ip: request.remote_ip
        )
      end

      def status_label(status)
        case status.to_i
        when 0 then 'anonymous'
        when 1 then 'active'
        when 2 then 'registered'
        when 3 then 'locked'
        else status.to_s
        end
      end
    end
  end
end
