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
    public class DuplicatesView : Gtk.Grid {
        Services.LibraryManager library_manager;

        Gtk.Box duplicates;

        uint timer_preview = 0;
        bool cance_preview = false;

        construct {
            library_manager = Services.LibraryManager.instance;
            library_manager.duplicate_found.connect ((hash) => {
                add_duplicate (hash);
            });
        }

        public DuplicatesView () {
            build_ui ();
        }

        private void build_ui () {
            duplicates = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            duplicates.margin = 24;

            var scroll = new Gtk.ScrolledWindow (null, null);
            scroll.expand = true;
            scroll.add (duplicates);

            this.add (scroll);
            this.show_all ();
        }

        public void reset () {
            cancel_create_previews_async.begin ();
            foreach (var item in duplicates.get_children ()) {
                duplicates.remove (item);
                item.destroy ();
            }
        }

        private void add_duplicate (string hash) {
            Idle.add (() => {
                lock (duplicates) {
                    foreach (var item in duplicates.get_children ()) {
                        if ((item as Widgets.DuplicateRow).hash == hash) {
                            return false;
                        }
                    }
                    var row = new Widgets.DuplicateRow (hash);
                    duplicates.pack_start (row);
                    create_previews.begin ();
                }
                return false;
            });
        }

        private async void create_previews () {
            lock (timer_preview) {
                if (timer_preview != 0 ){
                    Source.remove (timer_preview);
                    timer_preview = 0;
                }
                timer_preview = Timeout.add (1000, () => {
                    new Thread<void*> (null, () => {
                        foreach (var item in duplicates.get_children ()) {
                            var row = (item as Widgets.DuplicateRow);
                            row.create_previews ();
                            if (cance_preview) {
                                cance_preview = false;
                                return null;
                            }
                        }
                        return null;
                    });
                    Source.remove (timer_preview);
                    timer_preview = 0;
                    return false;
                });
            }
        }

        public async void cancel_create_previews_async () {
            cance_preview = true;
        }
    }
}