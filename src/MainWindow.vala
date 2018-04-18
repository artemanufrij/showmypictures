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
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
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

        public signal void ctrl_press ();
        public signal void ctrl_release ();

        Gtk.SearchEntry search_entry;
        Gtk.HeaderBar headerbar;
        Gtk.MenuButton app_menu;
        Gtk.MenuItem menu_item_reset;
        Gtk.MenuItem menu_item_resync;
        Gtk.Stack content;
        Gtk.Button navigation_button;
        Gtk.Button show_details;
        Gtk.Spinner spinner;

        Gtk.Image pane_show;
        Gtk.Image pane_hide;

        Widgets.Views.Welcome welcome;
        Widgets.Views.AlbumsView albums_view;
        Widgets.Views.AlbumView album_view;
        Widgets.Views.PictureView picture_view;
        Widgets.Views.DuplicatesView duplicates_view;
        Widgets.Views.NotFoundView not_found_view;
        Widgets.NavigationBar navigation;

        Popovers.Rename rename;

        Granite.Widgets.Toast app_notification;

        public bool ctrl_pressed { get; private set; default = false; }

        construct {
            settings = Settings.get_default ();
            settings.notify["use-dark-theme"].connect (
                () => {
                    Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = settings.use_dark_theme;
                    if (settings.use_dark_theme) {
                        app_menu.set_image (new Gtk.Image.from_icon_name ("open-menu-symbolic", Gtk.IconSize.LARGE_TOOLBAR));
                    } else {
                        app_menu.set_image (new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR));
                    }
                });
            settings.notify["show-picture-details"].connect (
                () => {
                    set_detail_button ();
                });

            library_manager = Services.LibraryManager.instance;
            library_manager.added_new_album.connect (
                (album) => {
                    Idle.add (
                        () => {
                            if (content.visible_child_name == "welcome") {
                                show_albums ();
                            }
                            return false;
                        });
                });
            library_manager.removed_album.connect (
                (album) => {
                    if ((content.visible_child_name == "album" && album_view.current_album == album) || (content.visible_child_name == "picture" && picture_view.current_picture.album == album)) {
                        if (library_manager.albums.length () > 0) {
                                show_albums ();
                        } else {
                            show_welcome ();
                        }
                    }
                });
            library_manager.sync_started.connect (
                () => {
                    spinner.active = true;
                    menu_item_resync.sensitive = false;
                    menu_item_reset.sensitive = false;
                });
            library_manager.sync_finished.connect (
                () => {
                    spinner.active = false;
                    menu_item_resync.sensitive = true;
                    menu_item_reset.sensitive = true;
                });

            this.key_press_event.connect (
                (event) => {
                    if (event.keyval == 65507) {
                        ctrl_pressed = true;
                        ctrl_press ();
                    }
                    return false;
                });

            this.key_release_event.connect (
                (event) => {
                    if (event.keyval == 65507) {
                        ctrl_pressed = false;
                        ctrl_release ();
                    }
                    return true;
                });
        }

        public MainWindow (bool open_files) {
            this.events |= Gdk.EventMask.POINTER_MOTION_MASK;
            this.events |= Gdk.EventMask.KEY_RELEASE_MASK;

            load_settings ();
            build_ui ();

            if (!open_files) {
                load_content_from_database.begin ();
            }

            this.configure_event.connect (
                (event) => {
                    if (settings.window_width == event.width && settings.window_height == event.height) {
                        return false;
                    }

                    settings.window_width = event.width;
                    settings.window_height = event.height;
                    if (content.visible_child_name == "picture") {
                        picture_view.calc_optimal_zoom ();
                    }
                    return false;
                });
            this.delete_event.connect (
                () => {
                    save_settings ();
                    return false;
                });

            Utils.set_custom_css_style (this.get_screen ());
        }

        private void build_ui () {
            headerbar = new Gtk.HeaderBar ();
            headerbar.show_close_button = true;
            headerbar.get_style_context ().add_class ("default-decoration");
            this.set_titlebar (headerbar);

            app_menu = new Gtk.MenuButton ();
            if (settings.use_dark_theme) {
                app_menu.set_image (new Gtk.Image.from_icon_name ("open-menu-symbolic", Gtk.IconSize.LARGE_TOOLBAR));
            } else {
                app_menu.set_image (new Gtk.Image.from_icon_name ("open-menu", Gtk.IconSize.LARGE_TOOLBAR));
            }

            var settings_menu = new Gtk.Menu ();

            var menu_item_library = new Gtk.MenuItem.with_label (_ ("Change Picture Folder…"));
            menu_item_library.activate.connect (
                () => {
                    var folder = library_manager.choose_folder ();
                    if (folder != null) {
                        settings.library_location = folder;
                        library_manager.scan_local_library_for_new_files (folder);
                    }
                });

            var menu_item_import = new Gtk.MenuItem.with_label (_ ("Import Pictures…"));
            menu_item_import.activate.connect (
                () => {
                    var folder = library_manager.choose_folder ();
                    if (folder != null) {
                        library_manager.scan_local_library_for_new_files (folder);
                    }
                });

            menu_item_reset = new Gtk.MenuItem.with_label (_ ("Reset all views"));
            menu_item_reset.activate.connect (
                () => {
                    reset_all_views ();
                    library_manager.reset_library ();
                });

            menu_item_resync = new Gtk.MenuItem.with_label (_ ("Resync Library"));
            menu_item_resync.activate.connect (
                () => {
                    library_manager.sync_library_content_async.begin (true);
                });

            var menu_item_preferences = new Gtk.MenuItem.with_label (_ ("Preferences"));
            menu_item_preferences.activate.connect (
                () => {
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
            search_entry.placeholder_text = _ ("Search Pictures");
            search_entry.margin_right = 5;
            search_entry.valign = Gtk.Align.CENTER;
            search_entry.search_changed.connect (
                () => {
                    switch (content.visible_child_name) {
                    case "albums" :
                        albums_view.filter = search_entry.text;
                        break;
                    case "album" :
                        album_view.filter = search_entry.text;
                        break;
                    }
                });
            headerbar.pack_end (search_entry);

            pane_show = new Gtk.Image.from_icon_name ("pane-show-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            pane_hide = new Gtk.Image.from_icon_name ("pane-hide-symbolic", Gtk.IconSize.LARGE_TOOLBAR);

            show_details = new Gtk.Button ();
            show_details.clicked.connect (
                () => {
                    toggle_details_action ();
                });
            set_detail_button ();
            headerbar.pack_end (show_details);

            spinner = new Gtk.Spinner ();
            headerbar.pack_end (spinner);

            content = new Gtk.Stack ();
            content.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;

            navigation_button = new Gtk.Button ();
            navigation_button.label = _ ("Back");
            navigation_button.valign = Gtk.Align.CENTER;
            navigation_button.can_focus = false;
            navigation_button.get_style_context ().add_class ("back-button");
            navigation_button.clicked.connect (
                () => {
                    back_action ();
                });
            headerbar.pack_start (navigation_button);

            welcome = new Widgets.Views.Welcome ();
            albums_view = new Widgets.Views.AlbumsView (this);
            albums_view.album_selected.connect (
                (album) => {
                    album_view.show_album (album);
                    show_album ();
                });
            album_view = new Widgets.Views.AlbumView (this);
            album_view.picture_selected.connect (
                (picture) => {
                    picture_view.show_picture (picture);
                    show_picture ();
                });

            picture_view = new Widgets.Views.PictureView ();
            picture_view.picture_loading.connect (
                () => {
                    spinner.active = true;
                });
            picture_view.picture_loaded.connect (
                (picture) => {
                    headerbar.title = Path.get_basename (picture.path);
                    spinner.active = false;
                });

            duplicates_view = new Widgets.Views.DuplicatesView ();
            duplicates_view.counter_changed.connect (
                (counter) => {
                    if (counter == 0) {
                        back_action ();
                    }
                    navigation.set_duplicates_counter (counter);
                });

            not_found_view = new Widgets.Views.NotFoundView ();
            not_found_view.counter_changed.connect (
                (counter) => {
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
            navigation.album_selected.connect (
                (album) => {
                    album_view.show_album (album, false);
                    show_album ();
                });
            navigation.date_selected.connect (
                (year, month, reload) => {
                    albums_view.date_filter (year, month);
                    if (reload) {
                        show_albums ();
                    }
                });
            navigation.label_selected.connect (
                (label) => {
                    albums_view.label_filter (label);
                    album_view.label_filter (label);
                    if (content.visible_child_name == "album" && album_view.visible_items == 0) {
                        show_albums ();
                    }
                });
            navigation.duplicates_selected.connect (
                () => {
                    show_duplicates ();
                });
            navigation.not_found_selected.connect (
                () => {
                    show_not_found ();
                });
            navigation.remove_all_not_found_items.connect (
                () => {
                    not_found_view.remove_all.begin ();
                });
            navigation.import_finished.connect (
                (name, imported) => {
                    send_app_notification (_ ("%u pictures from %s imported").printf (imported, name));
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
            if (!search_entry.is_focus && e.str.strip ().length > 0 && content.visible_child_name != "picture") {
                search_entry.grab_focus ();
            }
            return base.key_press_event (e);
        }

        private void set_detail_button () {
            if (settings.show_picture_details) {
                show_details.set_image (pane_hide);
                show_details.tooltip_text = _ ("Hide Picture Details [F4]");
            } else {
                show_details.set_image (pane_show);
                show_details.tooltip_text = _ ("Show Picture Details [F4]");
            }
        }

        private void show_duplicates () {
            content.visible_child_name = "duplicates";
            navigation_button.show ();
            show_details.show ();
            duplicates_view.hide_controls ();
        }

        private void show_not_found () {
            content.visible_child_name = "not_found";
            navigation_button.show ();
            show_details.hide ();
        }

        private void show_albums () {
            headerbar.title = _ ("Memories");
            content.visible_child_name = "albums";
            navigation_button.hide ();
            search_entry.show ();
            search_entry.text = albums_view.filter;
            navigation.reveal_child = true;
            show_details.hide ();
        }

        private void show_album () {
            headerbar.title = album_view.current_album.title;
            content.visible_child_name = "album";
            navigation_button.show ();
            search_entry.show ();
            search_entry.text = album_view.filter;
            navigation.reveal_child = true;
            show_details.hide ();
        }

        private void show_picture () {
            content.visible_child_name = "picture";
            navigation_button.show ();
            search_entry.hide ();
            navigation.reveal_child = false;
            if (settings.show_picture_details) {
                show_details.set_image (pane_hide);
                show_details.tooltip_text = _ ("Hide Picture Details [F4]");
            } else {
                show_details.set_image (pane_show);
                show_details.tooltip_text = _ ("Show Picture Details [F4]");
            }
            show_details.show ();
        }

        private void show_welcome () {
            headerbar.title = _ ("Memories");
            content.visible_child_name = "welcome";
            navigation_button.hide ();
            search_entry.hide ();
            navigation.reveal_child = false;
            show_details.hide ();
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
            show_details.hide ();
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

        public void open_file (File file) {
            var album = new Objects.Album ("Files");
            var current_picture = new Objects.Picture (album, true);
            string mime_type = "";
            try {
                var query_info = file.query_info (FileAttribute.STANDARD_CONTENT_TYPE, GLib.FileQueryInfoFlags.NONE);
                mime_type = query_info.get_content_type ();
            } catch (Error err) {
                warning (err.message);
            }
            current_picture.mime_type = mime_type;
            current_picture.source_type = Objects.SourceType.EXTERNAL;
            current_picture.path = file.get_path ();
            album.add_picture (current_picture);
            picture_view.show_picture (current_picture);
            show_picture ();

            new Thread<void*> (
                "open_file",
                () => {
                    File directory = File.new_for_uri (current_picture.file.get_parent ().get_uri ());
                    try {
                        var children = directory.enumerate_children ("standard::*", GLib.FileQueryInfoFlags.NONE);
                        FileInfo file_info;
                        while ((file_info = children.next_file ()) != null) {
                            mime_type = file_info.get_content_type ();
                            if (Utils.is_valid_mime_type (mime_type) && file_info.get_name () != file.get_basename ()) {
                                var picture = new Objects.Picture (album, true);
                                picture.mime_type = mime_type;
                                picture.source_type = Objects.SourceType.EXTERNAL;
                                picture.path = GLib.Path.build_filename (directory.get_path (), file_info.get_name ());
                                album.add_picture (picture);
                            }
                        }
                        children.close ();
                        children.dispose ();
                    } catch (Error err) {
                        warning (err.message);
                    }
                    directory.dispose ();
                    return null;
                });
        }

        public void open_files (File[] files, bool first_call = true) {
            content.transition_type = Gtk.StackTransitionType.NONE;
            if (files.length == 1 && files[0].query_exists ()) {
                open_file (files[0]);
            } else {
                var album = new Objects.Album ("Files");
                foreach (var file in files) {
                    var picture = new Objects.Picture (album, true);
                    picture.source_type = Objects.SourceType.EXTERNAL;
                    picture.path = file.get_path ();
                    album.add_picture (picture);
                }
                var picture = album.get_first_picture ();
                if (picture != null) {
                    picture_view.show_picture (picture);
                    show_picture ();
                }
            }
            content.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;
            if (first_call) {
                load_content_from_database.begin ();
            }
        }

        public void back_action () {
            switch (content.visible_child_name) {
            case "picture" :
                if (album_view.current_album != null) {
                    show_album ();
                } else {
                    show_albums ();
                }
                picture_view.save_changes ();
                break;
            case "not_found" :
            case "album" :
            case "duplicates" :
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
            } else if (content.visible_child_name == "albums") {
                albums_view.unselect_all ();
            } else if (content.visible_child_name == "album") {
                album_view.unselect_all ();
            }
        }

        public void toggle_details_action () {
            settings.show_picture_details = !settings.show_picture_details;
        }

        public void rotate_left_action () {
            if (content.visible_child_name == "picture") {
                picture_view.rotate_left ();
            }
        }

        public void rotate_right_action () {
            if (content.visible_child_name == "picture") {
                picture_view.rotate_right ();
            }
        }

        public void rename_action () {
            if (content.visible_child_name == "picture") {
                //picture_view.rename_picture ();
                if (rename == null) {
                    rename = new Popovers.Rename ();
                    rename.position = Gtk.PositionType.BOTTOM;
                    rename.set_relative_to (headerbar);
                }

                rename.rename_picture (picture_view.current_picture);
            }
        }

        private async void load_content_from_database () {
            if (library_manager.albums.length () > 0 && content.visible_child_name != "picture") {
                show_albums ();
            }
            new Thread<void*> (
                "load_content_from_database",
                () => {
                    uint i = 0;
                    foreach (var album in library_manager.albums) {
                        i += album.pictures.length ();
                    }

                    return null;
                });

            foreach (var album in library_manager.albums) {
                albums_view.add_album (album);
                navigation.add_album (album);
            }

            navigation.auto_refilter = true;

            library_manager.sync_library_content_async.begin ();
        }
    }
}
