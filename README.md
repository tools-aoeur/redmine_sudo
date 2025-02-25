Redmine Sudo plugin
===================

This plugin allows administrators of a redmine instance to change their rights temporarily and navigate as if they were normal users. Then they can take back their administrator rights only when needed. It's the same idea as "sudo" in Linux/Unix operating systems, you don't need to be root all the time.

The plugin also allows to define some CSS that will only be included when you're administrator, so that you can always obviously know your status. See below the 3rd screenshot, the proposed styles change the header background colors to red.

Screenshot
----------

Here's a screenshot when you're a standard user:

![redmine_sudo screenshot](http://jbbarth.com/screenshots/redmine_sudo_1.png)

If you click on it you become administrator:

![redmine_sudo screenshot](http://jbbarth.com/screenshots/redmine_sudo_2.png)

The admin section lets you define the title of the links and some CSS styles that will be applied only when admin:

![redmine_sudo screenshot](http://jbbarth.com/screenshots/redmine_sudo_3.png)

Installation
------------

See: http://www.redmine.org/projects/redmine/wiki/Plugins

**plugin requirement:**

Then you basically just have to:

* drop the plugin in the "plugins/" directory
* run `rake redmine:plugins:migrate`
* restart your redmine instance

Differences from original plugin code
-------------------------------------

* stripped away unneeded code. Minimalistic approach.
* no backwards compatibility targeted. We believe it's safer to keep the code lean and mean for the targeted redmine version
* removed dependency on deface. The deface plugin adds complexity and makes things difficult to manage with many plugins in action

Compatibility
-------------

This plugin only works with Redmine >= 5.1.0. If you have any issue, don't forget to mention the Redmine version you're using.

The redmine version needs to be patched with one view hook:

```diff
diff --git a/app/views/layouts/base.html.erb b/app/views/layouts/base.html.erb
index a307e6d2819..7e26aec7826 100644
--- a/app/views/layouts/base.html.erb
+++ b/app/views/layouts/base.html.erb
@@ -64,6 +64,7 @@
         <%= render_menu :account_menu -%>
     </div>
     <%= content_tag('div', "#{l(:label_logged_as)} #{link_to_user(User.current, :format => :username)}".html_safe, :id => 'loggedas') if User.current.logged? %>
+    <%= call_hook :view_layouts_base_top_menu %>
     <%= render_menu :top_menu if User.current.logged? || !Setting.login_required? -%>
 </div>
```

Test status
------------

|Plugin branch| Redmine Version   | Test Status      |
|-------------|-------------------|------------------|
|master       | 5.1.6             | [![5.1.6][1]][2]|

[1]: https://github.com/tools-aoeur/redmine_sudo/actions/workflows/5_1_6.yml/badge.svg
[2]: https://github.com/tools-aoeur/redmine_sudo/actions

Contribute
----------

If you like this plugin, it's a good idea to contribute:

* by giving feed back on what is cool, what should be improved
* by reporting bugs : you can open issues directly on github
* by forking it and sending pull request if you have a patch or a feature you want to implement
