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

        ShowMyPictures.Services.LibraryManager library_manager;

        public Objects.Album current_album { get; private set; }
        MainWindow mainwindow;

        Gtk.FlowBox pictures;

        private string _filter = "";
        public string filter {
            get {
                return _filter;
            } set {
                if (_filter != value) {
                    _filter = value;
                    pictures.invalidate_filter ();
                }
            }
        }

        public uint visible_items { get; set; default = 0; }

        uint timer_sort = 0;
        string filter_label = "";

        construct {
            library_manager = ShowMyPictures.Services.LibraryManager.instance;
        }

        public AlbumView (MainWindow mainwindow) {
            this.mainwindow = mainwindow;
            build_ui ();
        }

        private void build_ui () {
            pictures = new Gtk.FlowBox ();
            pictures.homogeneous = false;
            pictures.margin = 24;
            pictures.row_spacing = 12;
            pictures.column_spacing = 12;
            pictures.valign = Gtk.Align.START;
            pictures.selection_mode = Gtk.SelectionMode.MULTIPLE;
            pictures.set_filter_func (pictures_filter_func);
            pictures.child_activated.connect (show_picture_viewer);
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
                current_album.removed.disconnect (album_removed);
            }
            current_album = album;
            reset ();

            foreach (var picture in current_album.pictures) {
                add_picture (picture);
            }
            current_album.picture_added.connect (add_picture);
            current_album.removed.disconnect (album_removed);
        }

        public void reset () {
            foreach (var child in pictures.get_children ()) {
                (child as Widgets.Picture).picture.import_request.disconnect (import_request);
                child.destroy ();
            }
        }

        private void add_picture (Objects.Picture picture) {
            if (!picture.file_exists ()) {
                return;
            }
            Idle.add (
                () => {
                    var item = new Widgets.Picture (picture);
                    this.pictures.add (item);
                    picture.import_request.connect (import_request);
                    item.context_opening.connect (
                        () => {
                            if (!mainwindow.ctrl_pressed && !item.multi_selection) {
                                unselect_all ();
                            }
                        });
                    do_sort ();
                    return false;
                });
        }

        private void show_picture_viewer (Gtk.FlowBoxChild item) {
            if (mainwindow.ctrl_pressed) {
                (item as Widgets.Picture).toggle_multi_selection (false);
            } else {
                unselect_all ();
                picture_selected ((item as Widgets.Picture).picture);
            }
        }

        private void import_request () {
            foreach (var child in pictures.get_selected_children ()) {
                library_manager.import_from_external_device ((child as Widgets.Picture).picture);
            }
            unselect_all ();
        }

        private void do_sort () {
            if (timer_sort != 0) {
                Source.remove (timer_sort);
                timer_sort = 0;
            }

            timer_sort = Timeout.add (
                500,
                () => {
                    pictures.set_sort_func (pictures_sort_func);
                    pictures.set_sort_func (null);
                    if (timer_sort != 0) {
                        Source.remove (timer_sort);
                        timer_sort = 0;
                    }
                    return false;
                });
        }

        public void label_filter (string label) {
            if (filter_label != label) {
                filter_label = label;
                visible_items = 0;
                pictures.invalidate_filter ();
            }
        }

        private void album_removed () {
            current_album = null;
        }

        private int pictures_sort_func (Gtk.FlowBoxChild child1, Gtk.FlowBoxChild child2) {
            var item1 = (Widgets.Picture)child1;
            var item2 = (Widgets.Picture)child2;

            if (item1.picture.year != item2.picture.year) {
                return item1.picture.year - item2.picture.year;
            }
            if (item1.picture.month != item2.picture.month) {
                return item1.picture.month - item2.picture.month;
            }
            if (item1.picture.day != item2.picture.day) {
                return item1.picture.day - item2.picture.day;
            }
            if (item1.picture.hour != item2.picture.hour) {
                return item1.picture.hour - item2.picture.hour;
            }
            if (item1.picture.minute != item2.picture.minute) {
                return item1.picture.minute - item2.picture.minute;
            }
            if (item1.picture.second != item2.picture.second) {
                return item1.picture.second - item2.picture.second;
            }
            return item1.picture.path.collate (item2.picture.path);
        }

        private bool pictures_filter_func (Gtk.FlowBoxChild child) {
            if (filter.strip ().length == 0 && filter_label == "") {
                visible_items++;
                return true;
            }
            string[] filter_elements = filter.strip ().down ().split (" ");
            var picture = (child as Widgets.Picture).picture;
            foreach (string filter_element in filter_elements) {
                if (!picture.path.down ().contains (filter_element) && !picture.keywords.down ().contains (filter_element) && !picture.comment.down ().contains (filter_element)) {
                    return false;
                }
            }

            if (filter_label != "") {
                if (!picture.contains_keyword (filter_label) && !picture.album.contains_keyword (filter_label, false)) {
                    return false;
                }
            }
            visible_items++;
            return true;
        }

        public void unselect_all () {
            pictures.unselect_all ();
        }
    }
}
