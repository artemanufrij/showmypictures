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

        public double zoom { get; private set; default = 1; }
        public double optimal_zoom { get; private set; default = 1; }

        int current_width = 1;
        int current_height = 1;

        uint zoom_timer = 0;

        construct {
            library_manager = Services.LibraryManager.instance;
            settings = Settings.get_default ();
            settings.notify["show-picture-details"].connect (
                () => {
                    picture_details.reveal_child = settings.show_picture_details;
                });
        }

        public PictureView () {
            build_ui ();
            this.can_focus = true;
            this.draw.connect (first_draw);

            this.key_press_event.connect (
                (key) => {
                    switch (key.keyval) {
                    case Gdk.Key.Delete :
                        return delete_current_picture ();
                    case Gdk.Key.Left :
                        if (Gdk.ModifierType.MOD1_MASK in key.state) {
                            break;
                        }
                        show_prev_picture ();
                        return true;
                    case Gdk.Key.Right :
                        if (Gdk.ModifierType.MOD1_MASK in key.state) {
                            break;
                        }
                        show_next_picture ();
                        return true;
                    case Gdk.Key.c :
                        if (Gdk.ModifierType.CONTROL_MASK in key.state) {
                            Gtk.Clipboard.get_default (this.get_display ()).set_image (current_pixbuf);
                            return true;
                        }
                        break;
                    }

                    return false;
                });
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

        public bool delete_current_picture () {
            if (picture_details.has_text_focus || current_picture.source_type == Objects.SourceType.MTP || current_picture.source_type == Objects.SourceType.GPHOTO) {
                return false;
            }
            var for_delete = current_picture;
            if (!show_next_picture ()) {
                show_prev_picture ();
            }
            library_manager.db_manager.remove_picture (for_delete);
            return true;
        }

        private bool first_draw () {
            this.draw.disconnect (first_draw);
            calc_optimal_zoom ();
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
            scroll.add (drawing_area);
            event_box.add (scroll);

            picture_details = new Widgets.Views.PictureDetails ();
            picture_details.reveal_child = settings.show_picture_details;
            picture_details.next.connect (
                () => {
                    show_next_picture ();
                });
            picture_details.prev.connect (
                () => {
                    show_prev_picture ();
                });

            this.attach (event_box, 0, 0);
            this.attach (picture_details, 1, 0);
        }

        public bool on_draw (Cairo.Context cr) {
            if (current_picture == null) {
                return true;
            }

            if (current_picture.mime_type != "image/svg+xml") {
                cr.scale (zoom, zoom);
                Gdk.cairo_set_source_pixbuf (cr, current_pixbuf, 0, 0);
            } else {
                cr.scale (1, 1);
                Gdk.cairo_set_source_pixbuf (cr, new Gdk.Pixbuf.from_file_at_scale (current_picture.path, -1, (int)(zoom * current_pixbuf.width), true), 0, 0);
            }
            cr.paint ();
            return true;
        }

        public void show_picture (Objects.Picture picture) {
            if (current_picture == picture) {
                return;
            }

            save_changes ();

            if (current_picture != null) {
                disconnect_current_picture ();
            }
            picture_loading ();

            current_picture = picture;
            current_picture.exclude_exiv ();
            current_pixbuf = current_picture.original;
            drawing_area.tooltip_text = Uri.unescape_string (current_picture.path);

            calc_optimal_zoom (true);
            picture_details.show_picture (current_picture);
            picture_loaded (current_picture);
            current_picture.updated.connect (picture_updated);
            current_picture.rotated.connect (picture_reload);
            current_picture.external_modified.connect (picture_reload);
            current_picture.start_monitoring ();

            menu = null;

            this.grab_focus ();
        }

        private void disconnect_current_picture () {
            current_picture.stop_monitoring ();
            current_picture.updated.disconnect (picture_updated);
            current_picture.rotated.disconnect (picture_reload);
            current_picture.external_modified.disconnect (picture_reload);
        }

        private void picture_updated () {
            ShowMyPicturesApp.instance.mainwindow.send_app_notification (_ ("Picture properties updated"));
        }

        private void picture_reload () {
            disconnect_current_picture ();
            var p = current_picture;
            current_picture = null;
            show_picture (p);
        }

        public void reset () {
            current_picture = null;
            this.tooltip_text = "";
        }

        public void calc_optimal_zoom (bool force = false) {
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
            if (force) {
                zooming ();
            } else {
                do_zoom ();
            }
        }

        public void zoom_in () {
            if (zoom == 1 && current_picture.mime_type != "image/svg+xml") {
                return;
            }

            zoom += 0.1;
            if (zoom > 1 && current_picture.mime_type != "image/svg+xml") {
                zoom = 1;
            }
                    zooming ();
        }

        public void zoom_out () {
            if ( zoom == optimal_zoom) {
                return;
            }

            zoom -= 0.1;
            if (zoom < optimal_zoom && current_picture.mime_type != "image/svg+xml") {
                zoom = optimal_zoom;
                if (zoom > 1) {
                    zoom = 1;
                }
            }
                    zooming ();
        }

        private void do_zoom () {
            if (zoom_timer != 0) {
                Source.remove (zoom_timer);
                zoom_timer = 0;
            }

            zoom_timer = Timeout.add (
                250,
                () => {
                    zooming ();
                    Source.remove (zoom_timer);
                    zoom_timer = 0;
                    return false;
                });
        }

        private void zooming () {
            drawing_area.set_size_request ((int)(current_pixbuf.get_width () * zoom), (int)(current_pixbuf.get_height () * zoom));
            drawing_area.queue_draw ();
            center_scrollbars ();
        }

        private void center_scrollbars () {
            var va = scroll.get_vadjustment ();
            var ha = scroll.get_hadjustment ();

            va.changed.connect (
                () => {
                    va.set_value ((va.upper - va.page_size) / 2);
                });

            ha.changed.connect (
                () => {
                    ha.set_value ((ha.upper - ha.page_size) / 2);
                });
        }

        private bool show_context_menu (Gtk.Widget sender, Gdk.EventButton evt) {
            if (evt.type == Gdk.EventType.BUTTON_PRESS && evt.button == 3) {
                if (menu == null) {
                    menu = Utils.create_picture_menu (current_picture);
                }
                Utils.show_picture_menu (menu, current_picture);
                menu.popup (null, null, null, evt.button, evt.time);
                return true;
            }
            return false;
        }

        public void rotate_left () {
            current_picture.rotate_left_exiv ();
        }

        public void rotate_right () {
            current_picture.rotate_right_exiv ();
        }

        public void save_changes () {
            picture_details.save_changes ();
        }
    }
}
