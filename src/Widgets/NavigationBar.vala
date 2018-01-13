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

        public signal void album_selected (Objects.Album album);
        public signal void date_selected (int year, int month);
        public signal void duplicates_selected ();
        public signal void not_found_selected ();

        Granite.Widgets.SourceList folders { get; private set; }
        Granite.Widgets.SourceList.ExpandableItem events_entry;
        Granite.Widgets.SourceList.ExpandableItem device_entry;
        Granite.Widgets.SourceList.ExpandableItem extras_entry;
        Granite.Widgets.SourceList.Item duplicates_item;
        Granite.Widgets.SourceList.Item not_found_item;

        construct {
            library_manager = ShowMyPictures.Services.LibraryManager.instance;
            library_manager.added_new_album.connect (add_album);
            library_manager.duplicates_found.connect (
                () => {
                    if (!duplicates_item.visible) {
                        duplicates_item.visible = true;
                        extras_entry.expanded = true;
                    }
                });
            library_manager.non_exists_pictures_found.connect (
                () => {
                    not_found_item.visible = true;
                    extras_entry.expanded = true;
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
                        if (folder.parent is Widgets.NavigationDate) {
                            date_selected ((folder.parent as Widgets.NavigationDate).val, folder.val);
                        } else {
                            date_selected (folder.val, 0);
                        }
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

            not_found_item = new Granite.Widgets.SourceList.Item (_ ("Not Found"));
            not_found_item.icon = new ThemedIcon ("dialog-error-symbolic");
            not_found_item.visible = false;
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
                    }
                });
            folders.root.add (events_entry);

            content.attach (folders, 0, 0);
            content.attach (new Gtk.Separator (Gtk.Orientation.VERTICAL), 1, 0, 1, 2);

            this.transition_type = Gtk.RevealerTransitionType.SLIDE_RIGHT;
            this.add (content);
            this.show_all ();
        }

        public void reset () {
            duplicates_item.visible = false;
            not_found_item.visible = false;
            events_entry.clear ();
        }

        public void add_album (Objects.Album album) {
            Idle.add (
                () => {
                    if (album.year == 0) {
                        var album_item = new Widgets.NavigationAlbum (album);
                        events_entry.add (album_item);
                        return false;
                    }
                    var year = get_folder (album);
                    var month = year.get_subfolder (album);
                    var album_item = new Widgets.NavigationAlbum (album);
                    month.add (album_item);
                    return false;
                });
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
    }
}
