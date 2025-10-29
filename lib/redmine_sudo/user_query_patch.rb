require_dependency 'project' # see: http://www.redmine.org/issues/11035
require_dependency 'principal'
require_dependency 'user'
require_dependency 'user_query'

class UserQuery
  alias_method :available_columns_pre_plugin_sudo, :available_columns

  def available_columns
    return @available_columns if @available_columns

    @available_columns = available_columns_pre_plugin_sudo
    @available_columns << QueryColumn.new(:sudoer, sortable: "#{User.table_name}.sudoer")
    @available_columns
  end

  alias_method :initialize_available_filters_pre_plugin_sudo, :initialize_available_filters

  def initialize_available_filters
    initialize_available_filters_pre_plugin_sudo
    add_available_filter "sudoer",
      type: :list,
      values: [[l(:general_text_yes), '1'], [l(:general_text_no), '0']]
  end
end
