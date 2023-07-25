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

Compatibility
-------------

This plugin only works with Redmine >= 5.0.0. If you have any issue, don't forget to mention the Redmine version you're using.
The redmine version needs to be patched with 2 view hooks:

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
 
diff --git a/app/views/users/index.html.erb b/app/views/users/index.html.erb
index 82387d8ee2b..792568007a1 100644
--- a/app/views/users/index.html.erb
+++ b/app/views/users/index.html.erb
@@ -57,7 +57,7 @@
   <td class="firstname"><%= user.firstname %></td>
   <td class="lastname"><%= user.lastname %></td>
   <td class="email"><%= mail_to(user.mail) %></td>
-  <td class="tick"><%= checked_image user.admin? %></td>
+  <td class="tick"><%= checked_image user.admin? %><%= call_hook(:view_users_admin_extra, { user: user }) %></td>
   <% if Setting.twofa_required? || Setting.twofa_optional? %>
     <td class="twofa tick"><%= checked_image user.twofa_active? %></td>
   <% end %>
```

Test status
------------

|Plugin branch| Redmine Version   | Test Status      |
|-------------|-------------------|------------------|
|master       | 5.0.2             | [![5.0.2][1]][2]|

[1]: https://github.com/tools-aoeur/redmine_sudo/actions/workflows/5_0_2.yml/badge.svg
[2]: https://github.com/tools-aoeur/redmine_sudo/actions

Contribute
----------

If you like this plugin, it's a good idea to contribute:

* by giving feed back on what is cool, what should be improved
* by reporting bugs : you can open issues directly on github
* by forking it and sending pull request if you have a patch or a feature you want to implement
