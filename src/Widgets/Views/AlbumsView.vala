/*-
 * Copyright (c) 2017-2017 Artem Anufrij <artem.anufrij@live.de>
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
    public class AlbumsView : Gtk.Grid {
        ShowMyPictures.Services.LibraryManager library_manager;
        MainWindow mainwindow;

        public signal void album_selected (Objects.Album album);

        Gtk.FlowBox albums;

        private string _filter = "";
        public string filter {
            get {
                return _filter;
            } set {
                if (_filter != value) {
                    _filter = value;
                    albums.invalidate_filter ();
                }
            }
        }

        int filter_year = 0;
        int filter_month = 0;
        string filter_label = "";

        uint timer_sort = 0;

        construct {
            library_manager = ShowMyPictures.Services.LibraryManager.instance;
            library_manager.added_new_album.connect (
                (album) => {
                    Idle.add (
                        () => {
                            add_album (album);
                            return false;
                        });
                });
        }

        public AlbumsView (MainWindow mainwindow) {
            this.mainwindow = mainwindow;
            this.mainwindow.ctrl_press.connect (
                () => {
                    foreach (var child in albums.get_selected_children ()) {
                        var album = child as Widgets.Album;
                        if (!album.multi_selection) {
                            album.toggle_multi_selection (false);
                        }
                    }
                });
            build_ui ();
        }

        private void build_ui () {
            albums = new Gtk.FlowBox ();
            albums.margin = 24;
            albums.valign = Gtk.Align.START;
            albums.set_filter_func (albums_filter_func);
            albums.selection_mode = Gtk.SelectionMode.MULTIPLE;
            albums.max_children_per_line = 99;
            albums.row_spacing = 24;
            albums.column_spacing = 24;
            albums.child_activated.connect (show_album_viewer);
            albums.button_press_event.connect (
                () => {
                    if (!mainwindow.ctrl_pressed) {
                        unselect_all ();
                    }
                    return false;
                });

            var scroll = new Gtk.ScrolledWindow (null, null);
            scroll.expand = true;
            scroll.add (albums);

            this.add (scroll);
        }

        public void add_album (Objects.Album album) {
            var a = new Widgets.Album (album);
            lock (albums) {
                albums.add (a);
            }
            a.merge.connect (
                () => {
                    GLib.List<Objects.Album> selected = new GLib.List<Objects.Album> ();
                    foreach (var child in albums.get_selected_children ()) {
                        selected.append ((child as Widgets.Album).album);
                    }
                    album.merge (selected);
                });
            a.context_opening.connect (
                () => {
                    if (!mainwindow.ctrl_pressed) {
                        unselect_all ();
                    }
                });
            do_sort ();
        }

        private void show_album_viewer (Gtk.FlowBoxChild item) {
            if (mainwindow.ctrl_pressed) {
                if ((item as Widgets.Album).multi_selection) {
                    albums.unselect_child (item);
                    (item as Widgets.Album).reset ();
                    return;
                } else {
                    (item as Widgets.Album).toggle_multi_selection (false);
                }
            } else if (!(item as Widgets.Album).multi_selection) {
                foreach (var child in albums.get_selected_children ()) {
                    (child as Widgets.Album).reset ();
                }
                albums.unselect_all ();
                albums.select_child (item);
                album_selected ((item as Widgets.Album).album);
            }
        }

        public void reset () {
            foreach (var child in albums.get_children ()) {
                child.destroy ();
            }
        }

        private void do_sort () {
            lock (timer_sort) {
                if (timer_sort != 0) {
                    Source.remove (timer_sort);
                    timer_sort = 0;
                }

                timer_sort = Timeout.add (
                    500,
                    () => {
                        albums.set_sort_func (albums_sort_func);
                        albums.set_sort_func (null);
                        Source.remove (timer_sort);
                        timer_sort = 0;
                        return false;
                    });
            }
        }

        public void date_filter (int year, int month) {
            if (year != filter_year || month != filter_month) {
                filter_year = year;
                filter_month = month;
                albums.invalidate_filter ();
            }
        }

        public void label_filter (string label) {
            if (filter_label != label) {
                filter_label = label;
                albums.invalidate_filter ();
            }
        }

        private int albums_sort_func (Gtk.FlowBoxChild child1, Gtk.FlowBoxChild child2) {
            var item1 = (Widgets.Album)child1;
            var item2 = (Widgets.Album)child2;
            if (item1.year != item2.year) {
                return item2.year - item1.year;
            }
            if (item1.month != item2.month) {
                return item2.month - item1.month;
            }
            if (item1.day != item2.day) {
                return item2.day - item1.day;
            }
            return 0;
        }

        private bool albums_filter_func (Gtk.FlowBoxChild child) {
            if (filter.strip ().length == 0 && filter_year == 0 && filter_month == 0 && filter_label == "") {
                return true;
            }

            var album = (child as Widgets.Album).album;

            if (filter.strip ().length > 0) {
                string[] filter_elements = filter.strip ().down ().split (" ");
                foreach (string filter_element in filter_elements) {
                    if (!album.title.down ().contains (filter_element) && !album.keywords.down ().contains (filter_element)) {
                        bool picture_title = false;
                        foreach (var picture in album.pictures) {
                            if (picture.path.down ().contains (filter_element) || picture.keywords.down ().contains (filter_element) || picture.comment.down ().contains (filter_element)) {
                                picture_title = true;
                            }
                        }
                        if (picture_title) {
                            continue;
                        }
                        return false;
                    }
                }
            }

            if (filter_year > 0) {
                if (album.year != filter_year) {
                    return false;
                } else if (filter_month > 0 && album.month != filter_month) {
                    return false;
                }
            }

            if (filter_label != "") {
                if (!album.contains_keyword (filter_label)) {
                    return false;
                }
            }

            return true;
        }

        public void unselect_all () {
            foreach (var child in albums.get_selected_children ()) {
                (child as Widgets.Album).reset ();
            }
            albums.unselect_all ();
        }
    }
}
