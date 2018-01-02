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

namespace ShowMyPictures.Widgets {
    public class Picture : Gtk.FlowBoxChild {

        public Objects.Picture picture { get; private set; }

        Gtk.Image preview;

        public Picture (Objects.Picture picture) {
            this.picture = picture;
            this.picture.preview_created.connect (() => {
                preview.pixbuf = this.picture.preview;
                preview.show_all ();
            });
            build_ui ();
        }

        private void build_ui () {
            preview = new Gtk.Image ();
            preview.halign = Gtk.Align.CENTER;
            preview.get_style_context ().add_class ("card");
            preview.margin = 12;
            preview.pixbuf = picture.preview;

            this.add (preview);
        }
    }
}
