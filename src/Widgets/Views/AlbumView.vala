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
    public class AlbumView : Gtk.Grid {
        public signal void picture_selected (Objects.Picture picture);

        public Objects.Album current_album { get; private set; }

        Gtk.FlowBox pictures;

        public AlbumView () {
            build_ui ();
        }

        private void build_ui () {
            pictures = new Gtk.FlowBox ();
            pictures.homogeneous = false;
            pictures.set_sort_func (pictures_sort_func);
            pictures.margin = 24;
            pictures.row_spacing = 12;
            pictures.column_spacing = 12;
            pictures.valign = Gtk.Align.START;
            pictures.child_activated.connect ((child) => {
                picture_selected ((child as Widgets.Picture).picture);
            });
            var scroll = new Gtk.ScrolledWindow (null, null);
            scroll.add (pictures);
            scroll.expand = true;

            this.add (scroll);
        }

        public void show_album (Objects.Album album) {
            if (current_album == album) {
                return;
            }

            if (current_album != null) {
                current_album.picture_added.disconnect (add_picture);
            }
            current_album = album;
            reset ();

            foreach (var picture in current_album.pictures) {
                add_picture (picture);
            }

            current_album.picture_added.connect (add_picture);
        }

        private void reset () {
            foreach (var child in pictures.get_children ()) {
                child.destroy ();
            }
        }

        private void add_picture (Objects.Picture picture) {
            Idle.add (() => {
                var item = new Widgets.Picture (picture);
                this.pictures.add (item);
                item.show_all ();
                return false;
            });
        }

        private int pictures_sort_func (Gtk.FlowBoxChild child1, Gtk.FlowBoxChild child2) {
            var item1 = (Widgets.Picture)child1;
            var item2 = (Widgets.Picture)child2;
            return item1.picture.path.collate (item2.picture.path);
        }
    }
}
