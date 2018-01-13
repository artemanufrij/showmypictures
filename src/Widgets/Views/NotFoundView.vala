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
    public class NotFoundView : Gtk.Grid {
        Services.LibraryManager library_manager;

        public signal void items_cleared ();

        Gtk.FlowBox pictures;

        uint timer_preview = 0;
        bool cance_preview = false;

        construct {
            library_manager = Services.LibraryManager.instance;
            library_manager.picture_not_found.connect (add_picture);
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
            pictures.remove.connect (
                () => {
                    if (pictures.get_children ().length () == 0) {
                        items_cleared ();
                    }
                });

            var scroll = new Gtk.ScrolledWindow (null, null);
            scroll.expand = true;
            scroll.add (pictures);

            this.add (scroll);
            this.show_all ();
        }

        private void add_picture (Objects.Picture picture) {
            Idle.add (
                () => {
                    var item = new Widgets.Picture (picture);
                    this.pictures.add (item);
                    create_previews.begin ();
                    return false;
                });
        }

        public void remove_all () {
            cancel_create_previews_async.begin ();
            new Thread<void*> (
                "not_found_view_remove_all",
                () => {
                    foreach (var child in pictures.get_children ()) {
                        var picture = (child as Widgets.Picture).picture;
                        library_manager.db_manager.remove_picture (picture);
                    }
                    return null;
                });
        }

        private async void create_previews () {
            lock (timer_preview) {
                        cancel_preview_timer ();
                timer_preview = Timeout.add (
                    1000,
                    () => {
                        new Thread<void*> (
                            "not_found_view_create_previews",
                            () => {
                                foreach (var child in pictures.get_children ()) {
                                    var picture = (child as Widgets.Picture).picture;
                                    picture.create_preview ();
                                    if (cance_preview) {
                                        cance_preview = false;
                                        return null;
                                    }
                                }
                                return null;
                            });
                        cancel_preview_timer ();
                        return false;
                    });
            }
        }

        public async void cancel_create_previews_async () {
            cance_preview = true;
        }

        private void cancel_preview_timer () {
            lock (timer_preview) {
                if (timer_preview != 0 ) {
                    Source.remove (timer_preview);
                    timer_preview = 0;
                }
            }
        }
    }
}