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
    public class PictureDetails : Gtk.Revealer {

        Gtk.Label title;
        Gtk.Label date_size_resolution;
        Gtk.Label location;


        public PictureDetails () {
            build_ui ();
        }

        private void build_ui () {
            this.transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT;

            var content = new Gtk.Grid ();

            var scroll = new Gtk.ScrolledWindow (null, null);
            scroll.set_size_request (256 ,-1);

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            box.margin = 12;

            box.vexpand = true;
            scroll.add (box);

            title = new Gtk.Label ("");
            title.halign = Gtk.Align.START;

            date_size_resolution = new Gtk.Label ("");
            date_size_resolution.halign = Gtk.Align.START;

            location = new Gtk.Label ("");
            location.xalign = 0;
            location.wrap = true;
            location.wrap_mode = Pango.WrapMode.WORD_CHAR;

            content.attach (new Gtk.Separator (Gtk.Orientation.VERTICAL), 0, 0, 1, 2);
            content.attach (scroll, 1, 0);

            box.pack_start (date_size_resolution, false, false);
            box.pack_start (location, false, false);

            this.add (content);
            this.show_all ();
        }

        public void show_picture (Objects.Picture picture) {
            if (picture.date == null) {
                picture.exclude_creation_date ();
            }
            date_size_resolution.label = "%s\n%d × %d".printf (picture.date, picture.width, picture.height);
            location.label = picture.path;
        }
    }
}