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
    public class NavigationMobilePhone : Granite.Widgets.SourceList.ExpandableItem {
        Services.LibraryManager library_manager;

        Gtk.Menu menu;

        public Objects.MobilePhone mobile_phone { get; private set; }
        public Objects.Album album { get; private set; default = null; }

        construct {
            library_manager = Services.LibraryManager.instance;
        }

        public NavigationMobilePhone (Objects.MobilePhone mobile_phone) {
            this.mobile_phone = mobile_phone;
            this.name = mobile_phone.volume.get_name ();
            this.icon = mobile_phone.volume.get_icon ();
            album = new Objects.Album (this.name);

            this.mobile_phone.pictures_found.connect (
                (uri) => {
                    this.badge = mobile_phone.pictures.length ().to_string ();;
                    add_picture (uri);
                });

            this.badge = mobile_phone.pictures.length ().to_string ();
            build_menu ();

            foreach (string picture in mobile_phone.pictures) {
                add_picture (picture);
            }
        }

        private void add_picture (string uri) {
            lock (album) {
                var picture = new Objects.Picture (album);
                picture.path = uri;
                album.add_picture (picture);
            }
        }

        private void build_menu () {
            menu = new Gtk.Menu ();
            var remove_not_found_items = new Gtk.MenuItem.with_label (_ ("Import Pictures"));
            remove_not_found_items.activate.connect (
                () => {
                });
            menu.add (remove_not_found_items);
            menu.show_all ();
        }

        public override Gtk.Menu ? get_context_menu () {
            return menu;
        }
    }
}
