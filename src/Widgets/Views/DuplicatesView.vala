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
    public class DuplicatesView : Gtk.Grid {
        Services.LibraryManager library_manager;
        Settings settings;

        public signal void counter_changed (uint new_count);

        Gtk.Box duplicates;
        Widgets.Views.PictureDetails picture_details;

        construct {
            library_manager = Services.LibraryManager.instance;
            library_manager.duplicates_found.connect (add_duplicate);
            settings = Settings.get_default ();
            settings.notify["show-picture-details"].connect (
                () => {
                    picture_details.reveal_child = settings.show_picture_details;
                });
        }

        public DuplicatesView () {
            build_ui ();
        }

        private void build_ui () {
            duplicates = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            duplicates.valign = Gtk.Align.START;
            duplicates.margin = 24;
            duplicates.remove.connect_after (
                () => {
                    counter_changed (duplicates.get_children ().length ());
                });

            var scroll = new Gtk.ScrolledWindow (null, null);
            scroll.expand = true;
            scroll.add (duplicates);

            picture_details = new Widgets.Views.PictureDetails ();
            picture_details.reveal_child = settings.show_picture_details;

            this.attach (scroll, 0, 0);
            this.attach (picture_details, 1, 0);
            this.show_all ();
            picture_details.hide_controls ();
        }

        public void reset () {
            foreach (var item in duplicates.get_children ()) {
                duplicates.remove (item);
                item.destroy ();
            }
        }

        private void add_duplicate (GLib.List<string> hash_list) {
            Idle.add (
                () => {
                    lock (duplicates) {
                        foreach (var item in duplicates.get_children ()) {
                            duplicates.remove (item);
                            item.destroy ();
                        }
                        foreach (var hash in hash_list) {
                            var row = new Widgets.DuplicateRow (hash);
                            row.picture_selected.connect (
                                (picture) => {
                                    picture.exclude_exiv ();
                                    picture_details.show_picture (picture);
                                });
                            duplicates.pack_start (row, false, false);
                        }
                    }
                    counter_changed (hash_list.length ());
                    return false;
                });
        }

        public void hide_controls () {
            picture_details.hide_controls ();
        }
    }
}