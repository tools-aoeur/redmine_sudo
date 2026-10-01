# frozen_string_literal: true

module RedmineSudo
  # Core broadcasts "someone became/stopped being admin" and "the settings
  # changed" mails to `User.active.where(admin: true)`. Under this plugin that
  # column is expected to hold little more than a service account, while
  # sudoers are the people who actually administer the instance day to day --
  # so both groups must be notified.
  #
  # `Mailer.deliver_security_notification` is also used for personal notices
  # (your mail address changed, your password changed, ...) with a single
  # recipient, which must *not* be broadcast. Rather than restating core's
  # delivery conditions, `User#deliver_security_notification` flips the flag
  # below and the Mailer patch widens the recipient list only while it is set.
  module AdminNotification
    class Current < ActiveSupport::CurrentAttributes
      attribute :broadcast
    end

    def self.broadcast
      previous = Current.broadcast
      Current.broadcast = true
      yield
    ensure
      Current.broadcast = previous
    end

    def self.broadcast?
      Current.broadcast == true
    end

    # Everyone who can reach admin: the `admin` column plus the sudoers.
    def self.recipients
      User.active.where(admin: true).or(User.active.where(sudoer: true)).to_a
    end
  end
end
