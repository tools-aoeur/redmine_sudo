# frozen_string_literal: true

module RedmineSudo
  # Prepended onto `Mailer`'s singleton class: the two methods below are the
  # places where core mails "all administrators".
  module MailerPatch
    def deliver_security_notification(users, sender, options = {})
      users = AdminNotification.recipients if AdminNotification.broadcast?
      super
    end

    # Mirrors core's implementation, with the recipient list widened to
    # sudoers. Core computes the list inline, so there is no seam to hook.
    def deliver_settings_updated(sender, changes, options = {})
      return unless changes.present?

      # Symbols cannot be serialized:
      # ActiveJob::SerializationError: Unsupported argument type: Symbol
      changes = changes.map(&:to_s)
      # sender's remote_ip would be lost on serialization/deserialization
      # we have to pass it with options
      options[:remote_ip] ||= sender.remote_ip

      AdminNotification.recipients.each do |user|
        settings_updated(user, sender, changes, options).deliver_later
      end
    end
  end
end
