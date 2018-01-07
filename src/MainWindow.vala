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
        ShowMyPictures.Services.LibraryManager library_manager;
        ShowMyPictures.Settings settings;

        Gtk.SearchEntry search_entry;
        Gtk.HeaderBar headerbar;
        Gtk.MenuButton app_menu;
        Gtk.Stack content;
        Gtk.Button navigation_button;
        Gtk.Button rotate_left;
        Gtk.Button rotate_right;
        Gtk.Spinner spinner;

        Widgets.Views.Welcome welcome;
        Widgets.Views.AlbumsView albums_view;
        Widgets.Views.AlbumView album_view;
        Widgets.Views.PictureView picture_view;
        Widgets.NavigationBar navigation;

        construct {
            settings = ShowMyPictures.Settings.get_default ();
            settings.notify["use-dark-theme"].connect (() => {
                Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = settings.use_dark_theme;
                if (settings.use_dark_theme) {
                    app_menu.set_image (new Gtk.Image.from_icon_name ("open-menu-symbolic", Gtk.IconSize.LARGE_TOOLBAR));
                } else {
                    app_menu.set_image (new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR));
                }
            });

            library_manager = ShowMyPictures.Services.LibraryManager.instance;
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
                library_manager.sync_library_content.begin ();
            });

            this.configure_event.connect ((event) => {
                settings.window_width = event.width;
                settings.window_height = event.height;
                if (content.visible_child_name == "picture") {
                    picture_view.set_optimal_zoom ();
                }
                return false;
            });

            this.destroy.connect (() => {
                save_settings ();
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

            var menu_item_library = new Gtk.MenuItem.with_label(_("Change Video Folder…"));
            menu_item_library.activate.connect (() => {
                var folder = library_manager.choose_folder ();
                if(folder != null) {
                    settings.library_location = folder;
                    library_manager.scan_local_library_for_new_files (folder);
                }
            });

            var menu_item_import = new Gtk.MenuItem.with_label (_("Import Videos…"));
            menu_item_import.activate.connect (() => {
                var folder = library_manager.choose_folder ();
                if(folder != null) {
                    library_manager.scan_local_library_for_new_files (folder);
                }
            });

            var menu_item_preferences = new Gtk.MenuItem.with_label (_("Preferences"));
            menu_item_preferences.activate.connect (() => {
                var preferences = new Dialogs.Preferences (this);
                preferences.run ();
            });

            settings_menu.append (menu_item_library);
            settings_menu.append (menu_item_import);
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
                    picture_view.current_picture.rotate_left_exif ();
                }
            });
            rotate_right = new Gtk.Button.from_icon_name ("object-rotate-right-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            rotate_right.clicked.connect (() => {

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

            content.add_named (welcome, "welcome");
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
            grid.attach (navigation, 0, 0);

            this.add (grid);
            this.show_all ();

            show_welcome ();
        }

        public override bool key_press_event (Gdk.EventKey e) {
            if (!search_entry.is_focus && e.str.strip ().length > 0) {
                search_entry.grab_focus ();
            }
            return base.key_press_event (e);
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

        private void load_settings () {
            if (settings.window_maximized) {
                this.maximize ();
                this.set_default_size (1024, 720);
            } else {
                this.set_default_size (settings.window_width, settings.window_height);
            }

            this.window_position = Gtk.WindowPosition.CENTER;
            Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = settings.use_dark_theme;
        }

        private void save_settings () {
            settings.window_maximized = this.is_maximized;
        }

        public void back_action () {
            if (content.visible_child_name == "picture") {
                show_album ();
            } else if (content.visible_child_name == "album") {
                show_albums ();
            }
        }

        public void forward_action () {
            if (content.visible_child_name == "album" && picture_view.current_picture != null) {
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
