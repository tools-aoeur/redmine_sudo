# frozen_string_literal: true

module RedmineSudo::UserQueryPatch
  def initialize_available_filters
    super
    add_available_filter "sudoer",
      type: :list,
      values: [[l(:general_text_yes), '1'], [l(:general_text_no), '0']]
  end

  # Shows the `sudoer` column right next to `admin` by default, in addition to
  # core's own defaults.
  def default_columns_names
    names = super.dup
    admin_index = names.index(:admin)
    if admin_index && !names.include?(:sudoer)
      names.insert(admin_index + 1, :sudoer)
    end
    names
  end
end

