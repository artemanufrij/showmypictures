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
    public class NavigationBar : Gtk.Revealer {
        ShowMyPictures.Services.LibraryManager library_manager;

        public signal void remove_all_not_found_items ();
        public signal void album_selected (Objects.Album album);
        public signal void date_selected (int year, int month);
        public signal void label_selected (string label);
        public signal void duplicates_selected ();
        public signal void not_found_selected ();

        Granite.Widgets.SourceList folders { get; set; }
        Granite.Widgets.SourceList.ExpandableItem events_entry;
        Granite.Widgets.SourceList.ExpandableItem device_entry;
        Granite.Widgets.SourceList.ExpandableItem extras_entry;
        Granite.Widgets.SourceList.ExpandableItem labels_entry;
        Granite.Widgets.SourceList.Item duplicates_item;
        Widgets.NavigationNotFound not_found_item;

        public bool auto_refilter { get; set; default = false; }

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

            library_manager.db_manager.keywords_changed.connect (
                () => {
                    load_keywords ();
                });
        }

        public NavigationBar () {
            build_ui ();
        }

        private void build_ui () {
            var content = new Gtk.Grid ();

            folders = new Granite.Widgets.SourceList ();
            folders.hexpand = false;
            folders.width_request = 192;
            folders.item_selected.connect (
                (item) => {
                    if (item is Widgets.NavigationAlbum) {
                        album_selected ((item as Widgets.NavigationAlbum).album);
                    } else if (item is Widgets.NavigationDate) {
                        var folder = item as Widgets.NavigationDate;
                        label_selected ("");
                        if (folder.parent is Widgets.NavigationDate) {
                            date_selected ((folder.parent as Widgets.NavigationDate).val, folder.val);
                        } else {
                            date_selected (folder.val,                                    0);
                        }
                    } else if (item is Widgets.NavigationLabel) {
                            date_selected (0,                                             0);
                        label_selected ((item as Widgets.NavigationLabel).name);
                    } else if (item == duplicates_item) {
                        duplicates_selected ();
                    } else if (item == not_found_item) {
                        not_found_selected ();
                    }
                });

            extras_entry = new Granite.Widgets.SourceList.ExpandableItem (_ ("Extras"));
            extras_entry.expanded = true;
            folders.root.add (extras_entry);

            duplicates_item = new Granite.Widgets.SourceList.Item (_ ("Duplicates"));
            duplicates_item.icon = new ThemedIcon ("edit-copy-symbolic");
            duplicates_item.visible = false;
            extras_entry.add (duplicates_item);

            not_found_item = new Widgets.NavigationNotFound (_ ("Not Found"));
            not_found_item.icon = new ThemedIcon ("dialog-error-symbolic");
            not_found_item.visible = false;
            not_found_item.remove_all_not_found_items.connect (
                () => {
                    remove_all_not_found_items ();
                });
            extras_entry.add (not_found_item);

            device_entry = new Granite.Widgets.SourceList.ExpandableItem (_ ("Devices"));
            device_entry.expanded = true;
            folders.root.add (device_entry);

            events_entry = new Granite.Widgets.SourceList.ExpandableItem (_ ("Events"));
            events_entry.expanded = true;
            events_entry.toggled.connect (
                () => {
                    if (!events_entry.expanded) {
                        date_selected (0, 0);
                        events_entry.expanded = true;
                        folders.selected = null;
                    }
                });
            folders.root.add (events_entry);

            labels_entry = new Granite.Widgets.SourceList.ExpandableItem (_ ("Labels"));
            labels_entry.expanded = true;
            labels_entry.toggled.connect (
                () => {
                    label_selected ("");
                    labels_entry.expanded = true;
                    folders.selected = null;
                });
            folders.root.add (labels_entry);

            content.attach (folders, 0, 0);
            content.attach (new Gtk.Separator (Gtk.Orientation.VERTICAL), 1, 0, 1, 2);

            load_keywords ();

            this.transition_type = Gtk.RevealerTransitionType.SLIDE_RIGHT;
            this.add (content);
            this.show_all ();
        }

        public void reset () {
            duplicates_item.visible = false;
            not_found_item.visible = false;
            events_entry.clear ();
            labels_entry.clear ();
            folders.selected = null;
        }

        public void add_album (Objects.Album album) {
            if (album.year == 0) {
                var album_item = new Widgets.NavigationAlbum (album);
                events_entry.add (album_item);
                return;
            }
            var year = get_folder (album);
            var month = year.get_subfolder (album);
            var album_item = new Widgets.NavigationAlbum (album);
            month.add (album_item);
            if (auto_refilter) {
                folders.refilter ();
            }
        }

        private Widgets.NavigationDate get_folder (Objects.Album album) {
            foreach (var child in events_entry.children) {
                if (child is Widgets.NavigationDate) {
                    var folder = child as Widgets.NavigationDate;
                    if (folder.val == album.year) {
                        return folder;
                    }
                }
            }

            var new_child = new Widgets.NavigationDate (album.year.to_string (), album.year);
            events_entry.add (new_child);
            return new_child;
        }

        public void set_not_found_counter (uint counter) {
            if (counter > 0) {
                not_found_item.badge = counter.to_string ();
                not_found_item.visible = true;
                extras_entry.expanded = true;
            } else {
                not_found_item.badge = "";
                not_found_item.visible = false;
            }
        }

        public void set_duplicates_counter (uint counter) {
            if (counter > 0) {
                duplicates_item.badge = counter.to_string ();
                duplicates_item.visible = true;
                extras_entry.expanded = true;
            } else {
                duplicates_item.badge = "";
                duplicates_item.visible = false;
            }
        }

        private void load_keywords () {
            var keywords = library_manager.db_manager.get_keyword_collection ();

            // REMOVE NON EXISTS
            foreach (var item in labels_entry.children) {
                unowned List<string>? find = keywords.find_custom (item.name, strcmp);
                if (find == null || find.length () == 0) {
                    if (folders.selected != null && folders.selected.name == item.name) {
                        folders.selected = null;
                    }
                    labels_entry.remove (item);
                }
            }

            // ADD NEW
            foreach (var keyword in keywords) {
                if (!has_keyword (keyword)) {
                    var item = new Widgets.NavigationLabel (keyword);
                    labels_entry.add (item);
                }
            }
        }

        private bool has_keyword (string keyword) {
            foreach (var item in labels_entry.children) {
                if (item.name == keyword) {
                    return true;
                }
            }

            return false;
        }
    }
}
