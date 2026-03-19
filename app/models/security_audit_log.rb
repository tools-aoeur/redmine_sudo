# frozen_string_literal: true

class SecurityAuditLog < ActiveRecord::Base
  belongs_to :user

  # Table is append-only: no updates or deletes allowed
  before_update { raise ActiveRecord::ReadOnlyRecord }
  before_destroy { raise ActiveRecord::ReadOnlyRecord }

  validates :user_id, presence: true
  validates :user_login, presence: true
  validates :action, presence: true

  scope :chronological, -> { order(created_at: :desc) }

  # Log a security-relevant event.
  #   action:      short action key, e.g. "sudo_activated", "user_created"
  #   user:        the User performing the action (defaults to User.current)
  #   entity:      optional ActiveRecord object being acted upon
  #   entity_type: optional string override (for destroyed entities)
  #   entity_name: optional display name override
  #   details:     optional free-text details string
  #   remote_ip:   optional IP address string
  def self.log(action:, user: nil, entity: nil, entity_type: nil, entity_name: nil, details: nil, remote_ip: nil)
    user ||= User.current
    return if user.nil? || user.anonymous?

    create!(
      user_id: user.id,
      user_login: user.login,
      user_remote_ip: remote_ip,
      action: action.to_s,
      entity_type: entity_type || (entity.present? ? entity.class.name : nil),
      entity_id: entity.present? ? entity.id : nil,
      entity_name: entity_name || (entity.respond_to?(:name) ? entity.name : entity.try(:to_s)),
      details: details,
      created_at: Time.now.utc
    )
  rescue StandardError => e
    Rails.logger.error "SecurityAuditLog: failed to log '#{action}': #{e.message}"
  end
end
