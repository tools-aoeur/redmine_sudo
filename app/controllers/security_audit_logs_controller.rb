# frozen_string_literal: true

class SecurityAuditLogsController < ApplicationController
  before_action :require_admin
  layout 'admin'

  helper :sort
  include SortHelper

  def index
    sort_init 'created_at', 'desc'
    sort_update %w[created_at user_login action entity_type entity_name]

    @query = params[:q].to_s.strip
    @action_filter = params[:action_filter].to_s.strip
    @from = params[:from].to_s.strip
    @to = params[:to].to_s.strip

    scope = SecurityAuditLog.chronological

    if @query.present?
      q = "%#{@query}%"
      scope = scope.where(
        "user_login LIKE :q OR action LIKE :q OR entity_type LIKE :q OR entity_name LIKE :q OR details LIKE :q",
        q: q
      )
    end

    if @action_filter.present?
      scope = scope.where(action: @action_filter)
    end

    if @from.present?
      scope = scope.where("created_at >= ?", Time.parse(@from).utc)
    end

    if @to.present?
      scope = scope.where("created_at <= ?", Time.parse("#{@to} 23:59:59").utc)
    end

    @log_count = scope.count
    @limit = per_page_option
    @log_pages = Paginator.new @log_count, @limit, params['page']
    @logs = scope.reorder(sort_clause).limit(@limit).offset(@log_pages.offset).to_a

    @available_actions = SecurityAuditLog.distinct.pluck(:action).sort
  end
end
