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

        Gtk.Stack content;
        Widgets.Views.AlbumsView albums_view;
        Widgets.Views.Welcome welcome;

        construct {
            settings = ShowMyPictures.Settings.get_default ();
            library_manager = ShowMyPictures.Services.LibraryManager.instance;
            library_manager.added_new_album.connect ((album) => {
                Idle.add (() => {
                    if (content.visible_child_name == "welcome") {
                        content.visible_child_name = "albums";
                    }
                    return false;
                });
            });
        }

        public MainWindow () {
            this.events |= Gdk.EventMask.POINTER_MOTION_MASK;
            this.events |= Gdk.EventMask.KEY_RELEASE_MASK;

            load_settings ();
            build_ui ();

            load_content_from_database.begin ((obj, res) => {
                library_manager.sync_library_content.begin ();
            });

            this.destroy.connect (() => {
                save_settings ();
            });
        }

        private void build_ui () {
            content = new Gtk.Stack ();
            content.transition_type = Gtk.StackTransitionType.SLIDE_LEFT_RIGHT;

            welcome = new Widgets.Views.Welcome ();
            albums_view = new Widgets.Views.AlbumsView ();

            content.add_named (welcome, "welcome");
            content.add_named (albums_view, "albums");
            this.add (content);
            this.show_all ();
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

        private async void load_content_from_database () {
            foreach (var album in library_manager.albums) {
                albums_view.add_album (album);
                content.visible_child_name = "albums";
            }
        }
    }
}
