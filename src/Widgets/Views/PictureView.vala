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
        public Objects.Picture current_picture { get; private set; default = null; }

        public signal void picture_loading ();
        public signal void picture_loaded (Objects.Picture picture);

        Gdk.Pixbuf current_pixbuf = null;

        Gtk.Image image;
        Gtk.ScrolledWindow scroll;

        double zoom = 1;

        int current_width = 1;
        int current_height = 1;

        uint zoom_timer = 0;

        public PictureView () {
            build_ui ();
            this.draw.connect (first_draw);
            this.key_press_event.connect ((key) => {
                if (!(Gdk.ModifierType.MOD1_MASK in key.state) && current_picture != null) {
                    Objects.Picture next = null;
                    if (key.keyval == Gdk.Key.Left) {
                        next = current_picture.album.get_prev_picture (current_picture);
                    } else if (key.keyval == Gdk.Key.Right) {
                        next = current_picture.album.get_next_picture (current_picture);
                    }
                    if (next != null) {
                        show_picture (next);
                        return true;
                    }
                }
                return false;
            });
        }

        private bool first_draw () {
            this.draw.disconnect (first_draw);
            set_optimal_zoom ();
            return false;
        }

        private void build_ui () {
            scroll = new Gtk.ScrolledWindow (null, null);
            scroll.expand = true;
            scroll.scroll_event.connect ((key_event) => {
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

            image = new Gtk.Image ();
            image.get_style_context ().add_class ("card");
            scroll.add (image);

            this.add (scroll);
        }

        public void show_picture (Objects.Picture picture) {
            if (current_picture == picture) {
                return;
            }
            picture_loading ();

            current_picture = picture;
            current_picture.exclude_exif ();
            try {
                current_pixbuf = new Gdk.Pixbuf.from_file (current_picture.path);
                current_pixbuf = current_pixbuf.rotate_simple (Utils.get_rotation (current_picture));
            } catch (Error err) {
                warning (err.message);
            }

            set_optimal_zoom ();
            picture_loaded (current_picture);
        }

        public void set_optimal_zoom () {
            current_width = this.get_allocated_width ();
            current_height = this.get_allocated_height ();

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

            if (zoom > 1) {
                zoom = 1;
            } else if (zoom < 0.1) {
                zoom = 0.1;
            }
            do_zoom ();
        }

        public void zoom_in () {
            if (zoom < 1) {
                zoom += 0.1;
                do_zoom ();
            }
        }

        public void zoom_out () {
            if (zoom >= 0.2) {
                zoom -= 0.1;
                do_zoom ();
            }
        }

        private void do_zoom () {
            if (zoom_timer != 0) {
                Source.remove (zoom_timer);
                zoom_timer = 0;
            }

            zoom_timer = Timeout.add (100, () => {
                image.pixbuf = current_pixbuf.scale_simple ((int)(current_pixbuf.width * zoom), (int)(current_pixbuf.height * zoom), Gdk.InterpType.BILINEAR);
                Source.remove (zoom_timer);
                zoom_timer = 0;
                return false;
            });
        }
    }
}
