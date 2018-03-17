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
    public class NotFoundView : Gtk.Grid {
        Services.LibraryManager library_manager;

        public signal void counter_changed (uint new_count);

        Gtk.FlowBox pictures;

        construct {
            library_manager = Services.LibraryManager.instance;
            library_manager.pictures_not_found.connect (add_pictures);
        }

        public NotFoundView () {
            build_ui ();
        }

        private void build_ui () {
            pictures = new Gtk.FlowBox ();
            pictures.homogeneous = false;
            pictures.margin = 24;
            pictures.row_spacing = 12;
            pictures.column_spacing = 12;
            pictures.valign = Gtk.Align.START;
            pictures.remove.connect_after (
                () => {
                    counter_changed (pictures.get_children ().length ());
                });

            var scroll = new Gtk.ScrolledWindow (null, null);
            scroll.expand = true;
            scroll.add (pictures);

            this.add (scroll);
            this.show_all ();
        }

        private void add_pictures (GLib.List<Objects.Picture> missed_pictures) {
            Idle.add (
                () => {
                    foreach (var picture in missed_pictures) {
                        var item = new Widgets.Picture (picture);
                        pictures.add (item);
                    }
                    counter_changed (pictures.get_children ().length ());
                    return false;
                });
        }

        public async void remove_all () {
            foreach (var child in pictures.get_children ()) {
                var picture = (child as Widgets.Picture).picture;
                library_manager.db_manager.remove_picture (picture);
            }
        }
    }
}