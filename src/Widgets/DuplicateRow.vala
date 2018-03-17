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

namespace ShowMyPictures.Widgets {
    public class DuplicateRow : Gtk.ListBoxRow {
        Services.LibraryManager library_manager;

        public signal void picture_selected (Objects.Picture picture);

        public string hash { get; private set; }

        Gtk.FlowBox duplicates;

        construct {
            library_manager = Services.LibraryManager.instance;
        }

        public DuplicateRow (string hash) {
            this.hash = hash;
            build_ui ();
            find_pictures ();
        }

        private void build_ui () {
            duplicates = new Gtk.FlowBox ();
            duplicates.halign = Gtk.Align.START;
            duplicates.child_activated.connect (
                (child) => {
                    picture_selected ((child as Widgets.Picture).picture);
                });
            duplicates.set_sort_func (pictures_sort_func);
            this.add (duplicates);
            this.show_all ();
        }

        private void find_pictures () {
            foreach (var album in library_manager.albums) {
                foreach (var picture in album.pictures) {
                    if (picture.hash == hash) {
                        var pic = new Widgets.Picture (picture);
                        duplicates.add (pic);
                        duplicates.min_children_per_line = duplicates.get_children ().length ();
                        picture.removed.connect (
                            () => {
                                duplicates.remove (pic);
                                if (duplicates.get_children ().length () < 2) {
                                    this.destroy ();
                                }
                            });
                    }
                }
            }
        }

        private int pictures_sort_func (Gtk.FlowBoxChild child1, Gtk.FlowBoxChild child2) {
            var item1 = (Widgets.Picture)child1;
            var item2 = (Widgets.Picture)child2;
            return item1.picture.path.collate (item2.picture.path);
        }
    }
}