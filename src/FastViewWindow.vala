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
    public class FastViewWindow : Gtk.Window {
        Settings settings;

        Widgets.Views.PictureView picture_view;
        Gtk.Image pane_show;
        Gtk.Image pane_hide;
        Gtk.Button show_details;

        construct {
            settings = Settings.get_default ();
            settings.notify["show-picture-details"].connect (
                () => {
                    set_detail_button ();
                });
        }

        public FastViewWindow () {
            load_settings ();
            build_ui ();

            this.configure_event.connect (
                (event) => {
                    if (settings.fastview_window_width == event.width && settings.fastview_window_height == event.height) {
                        return false;
                    }

                    settings.fastview_window_width = event.width;
                    settings.fastview_window_height = event.height;
                    picture_view.calc_optimal_zoom ();

                    return false;
                });
            this.delete_event.connect (
                () => {
                    save_settings ();
                    return false;
                });
        }

        private void build_ui () {
            var headerbar = new Gtk.HeaderBar ();
            headerbar.show_close_button = true;
            this.set_titlebar (headerbar);

            pane_show = new Gtk.Image.from_icon_name ("pane-show-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
            pane_hide = new Gtk.Image.from_icon_name ("pane-hide-symbolic", Gtk.IconSize.SMALL_TOOLBAR);

            show_details = new Gtk.Button ();
            show_details.clicked.connect (
                () => {
                    toggle_details_action ();
                });
            set_detail_button ();
            headerbar.pack_end (show_details);

            picture_view = new Widgets.Views.PictureView ();
            picture_view.picture_loaded.connect (
                (picture) => {
                    headerbar.title = Path.get_basename (picture.path);
                });

            this.add (picture_view);
            this.show_all ();
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

        public void toggle_details_action () {
            settings.show_picture_details = !settings.show_picture_details;
        }

        public void rotate_left_action () {
            picture_view.rotate_left ();
        }

        public void rotate_right_action () {
            picture_view.rotate_right ();
        }

        public void open_file (File file) {
            var album = new Objects.Album ("Files");
            var current_picture = new Objects.Picture (album, true);
            current_picture.path = file.get_path ();
            current_picture.source_type = Objects.SourceType.EXTERNAL;
            album.add_picture (current_picture);
            picture_view.show_picture (current_picture);

            new Thread<void*> (
                "open_file",
                () => {
                    File directory = file.get_parent ();
                    try {
                        var children = directory.enumerate_children (FileAttribute.STANDARD_CONTENT_TYPE, GLib.FileQueryInfoFlags.NONE);
                        FileInfo file_info;
                        while ((file_info = children.next_file ()) != null) {
                            string mime_type = file_info.get_content_type ();
                            if (Utils.is_valid_mime_type (mime_type) && file_info.get_name () != file.get_basename ()) {
                                var picture = new Objects.Picture (album, true);
                                picture.mime_type = mime_type;
                                picture.path = GLib.Path.build_filename (directory.get_path (), file_info.get_name ());
                                picture.source_type = Objects.SourceType.EXTERNAL;
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

        public void open_files (File[] files) {
            if (files.length == 1 && files[0].query_exists ()) {
                open_file (files[0]);
            } else {
                var album = new Objects.Album ("Files");
                foreach (var file in files) {
                    var picture = new Objects.Picture (album, true);
                    picture.path = file.get_path ();
                    picture.source_type = Objects.SourceType.EXTERNAL;
                    album.add_picture (picture);
                }
                var picture = album.get_first_picture ();
                if (picture != null) {
                    picture_view.show_picture (picture);
                }
            }
        }

        private void load_settings () {
            if (settings.fastview_window_maximized) {
                this.maximize ();
                this.set_default_size (1024, 720);
            } else {
                this.set_default_size (settings.fastview_window_width, settings.fastview_window_height);
            }

            if (settings.fastview_window_x < 0 || settings.fastview_window_y < 0 ) {
                this.window_position = Gtk.WindowPosition.CENTER;
            } else {
                this.move (settings.fastview_window_x, settings.fastview_window_y);
            }

            Gtk.Settings.get_default ().gtk_application_prefer_dark_theme = settings.use_dark_theme;
        }

        private void save_settings () {
            settings.fastview_window_maximized = this.is_maximized;

            if (!settings.fastview_window_maximized) {
                int x, y;
                this.get_position (out x, out y);
                settings.fastview_window_x = x;
                settings.fastview_window_y = y;
            }
        }
    }
}