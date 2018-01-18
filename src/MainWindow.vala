/*-
 * Copyright (c) 2018-2018 Artem Anufrij <artem.anufrij@live.de>
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License as published by
 * the Free Software Foundation, either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU Lesser General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * The Noise authors hereby grant permission for non-GPL compatible
 * GStreamer plugins to be used and distributed together with GStreamer
 * and Noise. This permission is above and beyond the permissions granted
 * by the GPL license by which Noise is covered. If you modify this code
 * you may extend this exception to your version of the code, but you are not
 * obligated to do so. If you do not wish to do so, delete this exception
 * statement from your version.
 *
 * Authored by: Artem Anufrij <artem.anufrij@live.de>
 */

namespace ShowMyPictures {
    public class MainWindow : Gtk.Window {
        Services.LibraryManager library_manager;
        Settings settings;

        Gtk.SearchEntry search_entry;
        Gtk.HeaderBar headerbar;
        Gtk.MenuButton app_menu;
        Gtk.MenuItem menu_item_reset;
        Gtk.MenuItem menu_item_resync;
        Gtk.Stack content;
        Gtk.Button navigation_button;
        Gtk.Button rotate_left;
        Gtk.Button rotate_right;
        Gtk.Spinner spinner;

        Widgets.Views.Welcome welcome;
        Widgets.Views.AlbumsView albums_view;
        Widgets.Views.AlbumView album_view;
        Widgets.Views.PictureView picture_view;
        Widgets.Views.DuplicatesView duplicates_view;
        Widgets.Views.NotFoundView not_found_view;
        Widgets.NavigationBar navigation;

        Granite.Widgets.Toast app_notification;

        construct {
            settings = Settings.get_default ();
            settings.notify["use-dark-theme"].connect (() => {
                Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = settings.use_dark_theme;
                if (settings.use_dark_theme) {
                    app_menu.set_image (new Gtk.Image.from_icon_name ("open-menu-symbolic", Gtk.IconSize.LARGE_TOOLBAR));
                } else {
                    app_menu.set_image (new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR));
                }
            });

            library_manager = Services.LibraryManager.instance;
            library_manager.added_new_album.connect ((album) => {
                Idle.add (() => {
                    if (content.visible_child_name == "welcome") {
                        show_albums ();
                    }
                    return false;
                });
            });
            library_manager.removed_album.connect ((album) => {
                if ((content.visible_child_name == "album" && album_view.current_album == album) || (content.visible_child_name == "picture" && picture_view.current_picture.album == album)) {
                    if (library_manager.albums.length () > 0) {
                        show_albums ();
                    } else {
                        show_welcome ();
                    }
                }
            });
            library_manager.sync_started.connect (() => {
                spinner.active = true;
                menu_item_resync.sensitive = false;
                menu_item_reset.sensitive = false;
            });
            library_manager.sync_finished.connect (() => {
                spinner.active = false;
                menu_item_resync.sensitive = true;
                menu_item_reset.sensitive = true;
            });
        }

        public MainWindow () {
            this.events |= Gdk.EventMask.POINTER_MOTION_MASK;
            this.events |= Gdk.EventMask.KEY_RELEASE_MASK;

            load_settings ();
            build_ui ();

            Granite.Widgets.Utils.set_theming_for_screen (
                this.get_screen (),
                """
                    .album {
                        background: @base_color;
                        border-radius: 3px;
                    }
                """,
                Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
            );

            load_content_from_database.begin ((obj, res) => {
                if (settings.sync_files) {
                    library_manager.sync_library_content_async.begin ();
                } else if (library_manager.albums.length () > 0) {
                    library_manager.find_non_existent_items_async.begin ();
                    library_manager.scan_for_duplicates_async.begin ();
                    library_manager.sync_started ();
                }
            });

            this.configure_event.connect ((event) => {
                if (settings.window_width == event.width || settings.window_height == event.height) {
                    return false;
                }

                settings.window_width = event.width;
                settings.window_height = event.height;
                if (content.visible_child_name == "picture") {
                    picture_view.set_optimal_zoom ();
                }
                return false;
            });
            this.delete_event.connect (() => {
                save_settings ();
                return false;
            });
        }

        private void build_ui () {
            headerbar = new Gtk.HeaderBar ();
            headerbar.show_close_button = true;
            this.set_titlebar (headerbar);

            app_menu = new Gtk.MenuButton ();
            if (settings.use_dark_theme) {
                app_menu.set_image (new Gtk.Image.from_icon_name ("open-menu-symbolic", Gtk.IconSize.LARGE_TOOLBAR));
            } else {
                app_menu.set_image (new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR));
            }

            var settings_menu = new Gtk.Menu ();

            var menu_item_library = new Gtk.MenuItem.with_label(_("Change Picture Folder…"));
            menu_item_library.activate.connect (() => {
                var folder = library_manager.choose_folder ();
                if (folder != null) {
                    settings.library_location = folder;
                    library_manager.scan_local_library_for_new_files (folder);
                }
            });

            var menu_item_import = new Gtk.MenuItem.with_label (_("Import Pictures…"));
            menu_item_import.activate.connect (() => {
                var folder = library_manager.choose_folder ();
                if (folder != null) {
                    library_manager.scan_local_library_for_new_files (folder);
                }
            });

            menu_item_reset = new Gtk.MenuItem.with_label (_("Reset all views"));
            menu_item_reset.activate.connect (() => {
                reset_all_views ();
                library_manager.reset_library ();
            });

            menu_item_resync = new Gtk.MenuItem.with_label (_("Resync Library"));
            menu_item_resync.activate.connect (() => {
                library_manager.sync_library_content_async.begin ();
            });

            var menu_item_preferences = new Gtk.MenuItem.with_label (_("Preferences"));
            menu_item_preferences.activate.connect (() => {
                var preferences = new Dialogs.Preferences (this);
                preferences.run ();
            });

            settings_menu.append (menu_item_library);
            settings_menu.append (menu_item_import);
            settings_menu.append (new Gtk.SeparatorMenuItem ());
            settings_menu.append (menu_item_resync);
            settings_menu.append (menu_item_reset);
            settings_menu.append (new Gtk.SeparatorMenuItem ());
            settings_menu.append (menu_item_preferences);
            settings_menu.show_all ();

            app_menu.popup = settings_menu;
            headerbar.pack_end (app_menu);

            // SEARCH ENTRY
            search_entry = new Gtk.SearchEntry ();
            search_entry.placeholder_text = _("Search Pictures");
            search_entry.margin_right = 5;
            search_entry.search_changed.connect (() => {
                switch (content.visible_child_name) {
                    case "albums":
                        albums_view.filter = search_entry.text;
                        break;
                    case "album":
                        album_view.filter = search_entry.text;
                        break;
                }
            });
            headerbar.pack_end (search_entry);

            spinner = new Gtk.Spinner ();
            headerbar.pack_end (spinner);

            content = new Gtk.Stack ();
            content.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;

            navigation_button = new Gtk.Button ();
            navigation_button.label = _("Back");
            navigation_button.valign = Gtk.Align.CENTER;
            navigation_button.can_focus = false;
            navigation_button.get_style_context ().add_class ("back-button");
            navigation_button.clicked.connect (() => {
                back_action ();
            });

            headerbar.pack_start (navigation_button);

            rotate_left = new Gtk.Button.from_icon_name ("object-rotate-left-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            rotate_left.clicked.connect (() => {
                if (content.visible_child_name == "picture") {
                    picture_view.rotate_left ();
                }
            });
            rotate_right = new Gtk.Button.from_icon_name ("object-rotate-right-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            rotate_right.clicked.connect (() => {
                if (content.visible_child_name == "picture") {
                    picture_view.rotate_right ();
                }
            });

            headerbar.pack_start (rotate_left);
            headerbar.pack_start (rotate_right);

            welcome = new Widgets.Views.Welcome ();
            albums_view = new Widgets.Views.AlbumsView ();
            albums_view.album_selected.connect ((album) => {
                album_view.show_album (album);
                show_album ();
            });
            album_view = new Widgets.Views.AlbumView ();
            album_view.picture_selected.connect ((picture) => {
                picture_view.show_picture (picture);
                show_picture ();
            });

            picture_view = new Widgets.Views.PictureView ();
            picture_view.picture_loading.connect (() => {
                spinner.active = true;
            });
            picture_view.picture_loaded.connect ((picture) => {
                headerbar.title = Path.get_basename (picture.path);
                spinner.active = false;
            });

            duplicates_view = new Widgets.Views.DuplicatesView ();
            duplicates_view.counter_changed.connect ((counter) => {
                if (counter == 0) {
                    back_action ();
                }
                navigation.set_duplicates_counter (counter);
            });

            not_found_view = new Widgets.Views.NotFoundView ();
            not_found_view.counter_changed.connect ((counter) => {
                if (counter == 0) {
                    back_action ();
                }
                navigation.set_not_found_counter (counter);
            });

            content.add_named (welcome, "welcome");
            content.add_named (duplicates_view, "duplicates");
            content.add_named (not_found_view, "not_found");
            content.add_named (albums_view, "albums");
            content.add_named (album_view, "album");
            content.add_named (picture_view, "picture");

            var grid = new Gtk.Grid ();
            grid.attach (content, 1, 0);

            navigation = new Widgets.NavigationBar ();
            navigation.album_selected.connect ((album) => {
                album_view.show_album (album);
                show_album ();
            });
            navigation.date_selected.connect ((year, month) => {
                albums_view.date_filter (year, month);
                show_albums ();
            });
            navigation.duplicates_selected.connect (() => {
                show_duplicates ();
            });
            navigation.not_found_selected.connect (() => {
                show_not_found ();
            });
            navigation.remove_all_not_found_items.connect (() => {
                not_found_view.remove_all.begin ();
            });
            grid.attach (navigation, 0, 0);

            app_notification = new Granite.Widgets.Toast ("");
            var overlay = new Gtk.Overlay ();
            overlay.add (grid);
            overlay.add_overlay (app_notification);

            this.add (overlay);
            this.show_all ();

            show_welcome ();
        }

        public override bool key_press_event (Gdk.EventKey e) {
            if (!search_entry.is_focus && e.str.strip ().length > 0) {
                search_entry.grab_focus ();
            }
            return base.key_press_event (e);
        }

        private void show_duplicates () {
            content.visible_child_name = "duplicates";
            rotate_left.hide ();
            rotate_right.hide ();
            navigation_button.show ();
        }

        private void show_not_found () {
            content.visible_child_name = "not_found";
            rotate_left.hide ();
            rotate_right.hide ();
            navigation_button.show ();
        }

        private void show_albums () {
            headerbar.title = _("Show My Pictures");
            content.visible_child_name = "albums";
            navigation_button.hide ();
            rotate_left.hide ();
            rotate_right.hide ();
            search_entry.show ();
            search_entry.text = albums_view.filter;
            navigation.reveal_child = true;
        }

        private void show_album () {
            headerbar.title = album_view.current_album.title;
            content.visible_child_name = "album";
            navigation_button.show ();
            rotate_left.hide ();
            rotate_right.hide ();
            search_entry.show ();
            search_entry.text = album_view.filter;
            navigation.reveal_child = true;
        }

        private void show_picture () {
            content.visible_child_name = "picture";
            navigation_button.show ();
            rotate_left.show ();
            rotate_right.show ();
            search_entry.hide ();
            navigation.reveal_child = false;
        }

        private void show_welcome () {
            headerbar.title = _("Show My Pictures");
            content.visible_child_name = "welcome";
            navigation_button.hide ();
            rotate_left.hide ();
            rotate_right.hide ();
            search_entry.hide ();
            navigation.reveal_child = false;
        }

        private void reset_all_views () {
            search_entry.text = "";
            show_welcome ();
            duplicates_view.reset ();
            albums_view.reset ();
            album_view.reset ();
            picture_view.reset ();
            duplicates_view.reset ();
            navigation.reset ();
        }

        public void send_app_notification (string message) {
            app_notification.title = message;
            app_notification.send_notification ();
        }

        private void load_settings () {
            if (settings.window_maximized) {
                this.maximize ();
                this.set_default_size (1024, 720);
            } else {
                this.set_default_size (settings.window_width, settings.window_height);
            }

            if (settings.window_x < 0 || settings.window_y < 0 ) {
                this.window_position = Gtk.WindowPosition.CENTER;
            } else {
                this.move (settings.window_x, settings.window_y);
            }

            Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = settings.use_dark_theme;
        }

        private void save_settings () {
            settings.window_maximized = this.is_maximized;

            if (!settings.window_maximized) {
                int x, y;
                this.get_position (out x, out y);
                settings.window_x = x;
                settings.window_y = y;
            }
        }

        public void back_action () {
            switch (content.visible_child_name) {
                case "picture":
                    show_album ();
                    break;
                case "not_found":
                case "album":
                case "duplicates":
                    show_albums ();
                    break;
            }
        }

        public void forward_action () {
            if (content.visible_child_name == "album" && picture_view.current_picture != null && picture_view.current_picture.album == album_view.current_album) {
                show_picture ();
            } else if (content.visible_child_name == "albums" && album_view.current_album != null) {
                show_album ();
            }
        }

        public void reset_action () {
            if (search_entry.visible && search_entry.text != "") {
                search_entry.text = "";
            }
        }

        public void delete_action () {
            if (content.visible_child_name == "picture") {
                picture_view.delete_current_picture ();
            }
        }

        public void next_action () {
            if (content.visible_child_name == "picture") {
                picture_view.show_next_picture ();
            }
        }

        public void prev_action () {
            if (content.visible_child_name == "picture") {
                picture_view.show_prev_picture ();
            }
        }

        private async void load_content_from_database () {
            if (library_manager.albums.length () > 0) {
                show_albums ();
            }
            foreach (var album in library_manager.albums) {
                albums_view.add_album (album);
                navigation.add_album (album);
            }
        }
    }
}
