# Redmine Sudo plugin

Like `sudo` on Unix, this plugin lets Redmine administrators run as a normal user
most of the time and reclaim their admin rights only when needed. An admin can
temporarily drop privileges, browse the instance as a regular user, and toggle
back to admin in one click.

To make the current status obvious, the plugin can inject CSS that only applies
while you are acting as admin (for example, turning the header red).

## Screenshots

Acting as a standard user:

![Standard user](http://jbbarth.com/screenshots/redmine_sudo_1.png)

Click the link to become administrator:

![Administrator](http://jbbarth.com/screenshots/redmine_sudo_2.png)

The admin section lets you set the link titles and the admin-only CSS:

![Settings](http://jbbarth.com/screenshots/redmine_sudo_3.png)

## How it works

The plugin separates the *permission* to become admin from the *active* state:

- The native `admin` column keeps its native Redmine meaning: "currently acting
  as admin". Every Redmine permission check (`allowed_to?`, `safe_attributes`,
  API output, ...) already uses `admin?`/`admin`, so toggling it controls admin
  privileges without any override.
- An added `sudoer` column represents the permanent permission to become admin.

Both columns are edited independently, as two separate checkboxes ("Administrator"
and "Sudoer") on the Users admin form — checking or unchecking one never
affects the other. Checking "Administrator" directly grants active admin
rights, same as vanilla Redmine. Checking "Sudoer" only grants the
*permission* to become admin later via the Become Admin action below; it does
not activate `admin` itself, same as adding a user to `/etc/sudoers` doesn't
start them a root shell.


### Auto-drop via Redmine core's own SudoMode

Rather than adding a separate timer or setting, the toggle is wired directly
into Redmine's built-in `Redmine::SudoMode` password-reconfirmation feature
(the same one behind `sudo_mode` / `sudo_mode_timeout` in `configuration.yml`):

- **Become Admin** is gated by core's own `require_sudo_mode` check — if the
  user doesn't currently have a valid core sudo session (e.g. it's been more
  than `sudo_mode_timeout` minutes since they last logged in or reconfirmed
  their password), Redmine's own password form is shown; no custom UI.
- **Become User** (manual click, or the automatic drop below) flips `admin`
  off and forces the core sudo session to be considered expired
  (`session[:sudo_timestamp] = 0`), so the next sudo-gated action — including a
  future Become Admin — requires a fresh password.
- **Automatic drop**: a global `before_action` checks, on every request,
  whether the core sudo session has lapsed while `admin` is active; if so it
  drops `admin` the same way and logs a `sudo_expired` entry in the Security
  Audit Log. This check is read-only (it doesn't itself extend the session),
  so ordinary browsing doesn't keep admin alive indefinitely — only actual
  core `require_sudo_mode`-gated actions (Users, Settings, Roles, ...) do that,
  via their own native sliding behavior. API/token requests are exempt.

This means the feature only has an effect when `sudo_mode: true` is set in
`configuration.yml`; if core sudo mode is disabled, admin never auto-drops.

## Users list "Sudoer" column

The Administration > Users list shows core's default `admin` column
(plain Yes/No) as usual, plus a `sudoer` column shown right next to it by
default, so who currently has admin permission and who is merely eligible
to become admin are both visible at a glance without customizing the
query.

Filtering is unaffected: Redmine core's `admin` filter and this plugin's
`sudoer` filter still operate on the raw boolean columns.

## Installation

See the [Redmine plugin guide](http://www.redmine.org/projects/redmine/wiki/Plugins).
In short:

1. Drop the plugin into the `plugins/` directory.
2. Run `rake redmine:plugins:migrate`.
3. Restart your Redmine instance.

## Compatibility

Requires Redmine >= 6.1.0. When reporting an issue, always mention the Redmine
version you are using.

## Differences from the original plugin

- Stripped away unneeded code — minimalistic approach.
- No backwards compatibility targeted; the code stays lean and mean for the
  targeted Redmine version.
- Removed the `deface` dependency, which adds complexity and is hard to manage
  alongside many plugins.

## Test status

| Plugin branch | Redmine Version | Test Status      |
|---------------|-----------------|------------------|
| redmine-6.1   | 6.1.0           | [![6.1.0][1]][2] |

[1]: https://github.com/tools-aoeur/redmine_sudo/actions/workflows/6_1_0.yml/badge.svg
[2]: https://github.com/tools-aoeur/redmine_sudo/actions

## Contribute

Contributions are welcome:

- Give feedback on what works well and what could be improved.
- Report bugs by opening an issue on GitHub.
- Fork the project and send a pull request for patches or features.
