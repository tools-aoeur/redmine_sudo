# The `admin` column used to mean "currently acting as admin", so a sudoer who
# was elevated at the time of the upgrade carries a permanent `admin = true`.
# Elevation is now session state, and `admin` means "permanently an
# administrator, REST API included" -- so those rows must be cleared.
#
# Review `SELECT login FROM users WHERE admin = 1 AND sudoer = 1` before running
# this: every one of those accounts loses its permanent admin flag and keeps
# only the ability to elevate in the UI. If none of them should stay a
# permanent admin, the migration warns instead of refusing to run -- see the
# warning for how to grant one afterwards.
class ClearSessionElevationFromAdminColumn < ActiveRecord::Migration[7.2]
  def up
    t = connection.quoted_true
    f = connection.quoted_false

    # Not a hard stop: an instance with no permanent admin left can still
    # recover via "Become Admin" (sudo grace period) or a console/rake fix.
    if select_value("SELECT COUNT(*) FROM users WHERE admin = #{t} AND sudoer = #{f}").to_i.zero?
      say 'redmine_sudo: this migration leaves no permanent administrator. ' \
          'Grant "Administrator" (without "Sudoer") to at least one account ' \
          '-- ideally a dedicated service account -- or the REST API and ' \
          'every administration screen become unreachable.', true
    end

    execute "UPDATE users SET admin = #{f} WHERE admin = #{t} AND sudoer = #{t}"
  end

  def down
    # The cleared flags were ephemeral "currently elevated" state; there is
    # nothing meaningful to restore.
  end
end
