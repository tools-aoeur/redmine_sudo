# frozen_string_literal: true

module RedmineSudo::UserQueryPatch
  def initialize_available_filters
    super
    add_available_filter "sudoer",
      type: :list,
      values: [[l(:general_text_yes), '1'], [l(:general_text_no), '0']]
  end
end
