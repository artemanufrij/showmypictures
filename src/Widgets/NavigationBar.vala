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

        public Granite.Widgets.SourceList folders { get; private set; }
        public Granite.Widgets.SourceList.ExpandableItem events_entry;
        public Granite.Widgets.SourceList.ExpandableItem device_entry;
        public Granite.Widgets.SourceList.ExpandableItem extras_entry;

        construct {
            library_manager = ShowMyPictures.Services.LibraryManager.instance;
            library_manager.added_new_album.connect ((album) => {
                Idle.add (() => {
                    add_album (album);
                    return false;
                });
            });
            library_manager.duplicates_found.connect (() => {

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
            folders.item_selected.connect ((item) => {
                if (item is Widgets.NavigationAlbum) {
                    album_selected ((item as Widgets.NavigationAlbum).album);
                } else {
                    var folder = item as Widgets.NavigationDate;
                    if (folder.parent is Widgets.NavigationDate) {
                        date_selected ((folder.parent as Widgets.NavigationDate).val, folder.val);
                    } else {
                        date_selected (folder.val, 0);
                    }
                }
            });

            extras_entry = new Granite.Widgets.SourceList.ExpandableItem (_("Extras"));
            extras_entry.expanded = true;
            folders.root.add (extras_entry);

            var duplicates_item = new Granite.Widgets.SourceList.Item (_("Duplicates"));
            duplicates_item.icon = new ThemedIcon ("edit-copy-symbolic");
            extras_entry.add (duplicates_item);

            device_entry = new Granite.Widgets.SourceList.ExpandableItem (_("Devices"));
            device_entry.expanded = true;
            folders.root.add (device_entry);

            events_entry = new Granite.Widgets.SourceList.ExpandableItem (_("Events"));
            events_entry.expanded = true;
            events_entry.toggled.connect (() => {
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
