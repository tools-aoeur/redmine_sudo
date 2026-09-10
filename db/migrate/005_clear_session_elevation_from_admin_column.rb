# The `admin` column used to mean "currently acting as admin", so a sudoer who
# was elevated at the time of the upgrade carries a permanent `admin = true`.
# Elevation is now session state, and `admin` means "permanently an
# administrator, REST API included" -- so those rows must be cleared.
#
# Review `SELECT login FROM users WHERE admin = 1 AND sudoer = 1` before running
# this: every one of those accounts loses its permanent admin flag and keeps
# only the ability to elevate in the UI.
class ClearSessionElevationFromAdminColumn < ActiveRecord::Migration[7.2]
  def up
    t = connection.quoted_true
    f = connection.quoted_false

    # Check before writing: MySQL has no transactional DDL, so a failure after
    # the UPDATE would leave the instance without any administrator at all.
    if select_value("SELECT COUNT(*) FROM users WHERE admin = #{t} AND sudoer = #{f}").to_i.zero?
      raise 'redmine_sudo: no permanent administrator would be left. Grant ' \
            '"Administrator" (without "Sudoer") to at least one account -- ' \
            'ideally a dedicated service account -- before running this ' \
            'migration, otherwise the REST API and every administration ' \
            'screen become unreachable.'
    end

    execute "UPDATE users SET admin = #{f} WHERE admin = #{t} AND sudoer = #{t}"
  end

  def down
    # The cleared flags were ephemeral "currently elevated" state; there is
    # nothing meaningful to restore.
  end
end
