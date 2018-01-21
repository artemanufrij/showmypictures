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

namespace ShowMyPictures.Widgets.Views {
    public class PictureView : Gtk.Grid {
        Services.LibraryManager library_manager;
        Settings settings;

        public Objects.Picture current_picture { get; private set; default = null; }

        public signal void picture_loading ();
        public signal void picture_loaded (Objects.Picture picture);

        Gdk.Pixbuf current_pixbuf = null;

        Gtk.ScrolledWindow scroll;
        Gtk.DrawingArea drawing_area;
        Widgets.Views.PictureDetails picture_details;
        Gtk.Menu menu;
        Gtk.Menu open_with;

        double zoom = 1;
        double optimal_zoom = 1;

        int current_width = 1;
        int current_height = 1;

        uint zoom_timer = 0;

        construct {
            library_manager = Services.LibraryManager.instance;
            settings = Settings.get_default ();
        }

        public PictureView () {
            build_ui ();
            this.draw.connect (first_draw);
        }

        public bool show_next_picture () {
            var pic = current_picture.album.get_next_picture (current_picture);
            if (pic != null) {
                show_picture (pic);
                return true;
            }

            return false;
        }

        public bool show_prev_picture () {
            var pic = current_picture.album.get_prev_picture (current_picture);
            if (pic != null) {
                show_picture (pic);
                return true;
            }

            return false;
        }

        public void delete_current_picture () {
            if (picture_details.has_text_focus) {
                return;
            }
            var for_delete = current_picture;
            if (!show_next_picture ()) {
                show_prev_picture ();
            }
            library_manager.db_manager.remove_picture (for_delete);
        }

        private bool first_draw () {
            this.draw.disconnect (first_draw);
            set_optimal_zoom ();
            return false;
        }

        private void build_ui () {
            var event_box = new Gtk.EventBox ();
            event_box.button_press_event.connect (show_context_menu);

            scroll = new Gtk.ScrolledWindow (null, null);
            scroll.expand = true;
            scroll.scroll_event.connect (
                (key_event) => {
                    if (Gdk.ModifierType.CONTROL_MASK in key_event.state) {
                        if (key_event.delta_y < 0) {
                            zoom_in ();
                        } else {
                            zoom_out ();
                        }
                        return true;
                    }
                    return false;
                });

            drawing_area = new Gtk.DrawingArea ();
            drawing_area.halign = Gtk.Align.CENTER;
            drawing_area.valign = Gtk.Align.CENTER;
            drawing_area.draw.connect (on_draw);
            drawing_area.can_focus = true;
            scroll.add (drawing_area);
            event_box.add (scroll);

            menu = new Gtk.Menu ();

            var menu_open_with = new Gtk.MenuItem.with_label (_ ("Open with"));
            open_with = new Gtk.Menu ();
            menu_open_with.set_submenu (open_with);
            menu.add (menu_open_with);

            var menu_new_cover = new Gtk.MenuItem.with_label (_ ("Set as Album picture"));
            menu_new_cover.activate.connect (
                () => {
                    current_picture.album.set_new_cover_from_picture (current_picture);
                    ShowMyPicturesApp.instance.mainwindow.send_app_notification (_ ("Album cover changed"));
                });

            var menu_open_loacation = new Gtk.MenuItem.with_label (_ ("Open location"));
            menu_open_loacation.activate.connect (
                () => {
                    var folder = Path.get_dirname (current_picture.path);
                    try {
                        Process.spawn_command_line_async ("xdg-open '%s'".printf (folder));
                    } catch (Error err) {
                        warning (err.message);
                    }
                });

            var menu_move_into_trash = new Gtk.MenuItem.with_label (_ ("Move into Trash"));
            menu_move_into_trash.activate.connect (
                () => {
                    library_manager.db_manager.remove_picture (current_picture);
                });

            menu.add (menu_new_cover);
            menu.add (new Gtk.SeparatorMenuItem ());
            menu.add (menu_open_loacation);
            menu.add (menu_move_into_trash);
            menu.show_all ();

            picture_details = new Widgets.Views.PictureDetails ();
            picture_details.reveal_child = settings.show_picture_details;
            this.attach (event_box, 0, 0);
            this.attach (picture_details, 1, 0);
        }

        public bool on_draw (Cairo.Context cr) {
            stdout.printf ("draw\n");
            if (current_picture == null) {
                return true;
            }

            cr.scale (zoom, zoom);
            Gdk.cairo_set_source_pixbuf (cr, current_pixbuf, 0, 0);
            cr.paint ();
            return true;
        }

        public void show_picture (Objects.Picture picture) {
            if (current_picture == picture) {
                return;
            }

            picture_details.save_changes ();

            if (current_picture != null) {
                current_picture.updated.disconnect (picture_updated);
            }
            picture_loading ();

            current_picture = picture;
            current_picture.exclude_exiv ();
            try {
                current_pixbuf = new Gdk.Pixbuf.from_file (current_picture.path);
                var r = Utils.get_rotation (current_picture);
                if (r != Gdk.PixbufRotation.NONE) {
                    current_pixbuf = current_pixbuf.rotate_simple (r);
                }
            } catch (Error err) {
                warning (err.message);
            }
            drawing_area.tooltip_text = current_picture.path;

            set_optimal_zoom ();
            picture_details.show_picture (current_picture);
            picture_loaded (current_picture);
            current_picture.updated.connect (picture_updated);

            drawing_area.grab_focus ();
        }

        private void picture_updated () {
            ShowMyPicturesApp.instance.mainwindow.send_app_notification (_ ("Picture properties updated"));
        }

        public void reset () {
            current_picture = null;
            this.tooltip_text = "";
        }

        public void set_optimal_zoom () {
            current_width = scroll.get_allocated_width ();
            current_height = scroll.get_allocated_height ();

            if (current_width == 1 && current_height == 1) {
                return;
            }

            var rel_scroll = (double)current_height / (double)current_width;
            var rel_picture = (double)current_pixbuf.height / (double)current_pixbuf.width;

            if (rel_scroll > rel_picture) {
                zoom = (double)current_width / (double)current_pixbuf.width;
            } else {
                zoom = (double)current_height / (double)current_pixbuf.height;
            }

            optimal_zoom = zoom;

            if (zoom > 1) {
                zoom = 1;
            } else if (zoom < 0.1) {
                zoom = 0.1;
            }
            do_zoom ();
        }

        public void zoom_in () {
            if (zoom == 1) {
                return;
            }

            zoom += 0.1;
            if (zoom > 1) {
                zoom = 1;
            }
            do_zoom ();
        }

        public void zoom_out () {
            if ( zoom == optimal_zoom) {
                return;
            }

            zoom -= 0.1;
            if (zoom < optimal_zoom) {
                zoom = optimal_zoom;
            }
            do_zoom ();
        }

        private void do_zoom () {
            if (zoom_timer != 0) {
                Source.remove (zoom_timer);
                zoom_timer = 0;
            }

            zoom_timer = Timeout.add (
                100,
                () => {
                    drawing_area.set_size_request ((int)(current_pixbuf.get_width ()*zoom), (int)(current_pixbuf.get_height ()*zoom));
                    drawing_area.queue_draw ();
                    center_scrollbars ();
                    Source.remove (zoom_timer);
                    zoom_timer = 0;
                    return false;
                });
        }

        private void center_scrollbars () {
            var va = scroll.get_vadjustment ();
            var ha = scroll.get_hadjustment ();

            va.changed.connect (
                () => {
                    va.set_value ((va.upper - va.page_size)/2);
                });

            ha.changed.connect (
                () => {
                    ha.set_value ((ha.upper - ha.page_size)/2);
                });
        }

        public void toggle_picture_details () {
            picture_details.reveal_child = !picture_details.reveal_child;
            settings.show_picture_details = picture_details.reveal_child;
        }

        private bool show_context_menu (Gtk.Widget sender, Gdk.EventButton evt) {
            if (evt.type == Gdk.EventType.BUTTON_PRESS && evt.button == 3) {
                foreach (var child in open_with.get_children ()) {
                    child.destroy ();
                }

                var f = File.new_for_path (current_picture.path);

                foreach (var appinfo in AppInfo.get_all_for_type (current_picture.mime_type)) {
                    var item = new Gtk.MenuItem.with_label (appinfo.get_name ());
                    item.activate.connect (
                        () => {
                            GLib.List<File> files = new GLib.List<File> ();
                            files.append (f);
                            try {
                                appinfo.launch (files, null);
                            } catch (Error err) {
                                warning (err.message);
                            }
                        });
                    open_with.add (item);
                }
                open_with.show_all ();

                menu.popup (null, null, null, evt.button, evt.time);
                return true;
            }
            return false;
        }

        public void rotate_left () {
            if (current_picture.rotate_left_exiv ()) {
                var p = current_picture;
                current_picture = null;
                show_picture (p);
            }
        }

        public void rotate_right () {
            if (current_picture.rotate_right_exiv ()) {
                var p = current_picture;
                current_picture = null;
                show_picture (p);
            }
        }
    }
}
