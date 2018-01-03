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

        Objects.Picture current_picture;
        Gdk.Pixbuf current_pixbuf = null;

        Gtk.Image image;
        Gtk.ScrolledWindow scroll;

        double zoom = 1;

        public PictureView () {
            build_ui ();
        }

        private void build_ui () {
            scroll = new Gtk.ScrolledWindow (null, null);
            scroll.expand = true;

            image = new Gtk.Image ();
            image.get_style_context ().add_class ("card");
            scroll.add (image);

            this.add (scroll);
        }

        public void show_picture (Objects.Picture picture) {
            if (current_picture == picture) {
                return;
            }
            current_picture = picture;
            try {
                current_pixbuf = new Gdk.Pixbuf.from_file (current_picture.path);
            } catch (Error err) {
                warning (err.message);
            }
            image.pixbuf = current_pixbuf;
        }

        public void zoom_in () {
            if (zoom < 1) {
                zoom += 0.1;
                image.pixbuf = current_pixbuf.scale_simple ((int)(current_pixbuf.width * zoom), (int)(current_pixbuf.height * zoom), Gdk.InterpType.BILINEAR);
            }
        }

        public void zoom_out () {
            if (zoom >= 0.2) {
                zoom -= 0.1;
                image.pixbuf = current_pixbuf.scale_simple ((int)(current_pixbuf.width * zoom), (int)(current_pixbuf.height * zoom), Gdk.InterpType.BILINEAR);
            }
        }
    }
}
