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
    public class NavigationExternalDevice : Granite.Widgets.SourceList.ExpandableItem {
        Services.LibraryManager library_manager;

        public signal void import_started ();
        public signal void import_finished ();
        public signal void import_counter (uint count);

        Gtk.Menu menu;

        public Objects.ExternalDevice device { get; private set; }
        public Objects.Album album { get; private set; default = null; }

        construct {
            library_manager = Services.LibraryManager.instance;
            import_started.connect (
                () => {
                    this.name = _ ("…importing");
                });
            import_finished.connect (
                () => {
                    Idle.add (
                        () => {
                            this.name = device.volume.get_name ();
                            return false;
                        });
                });
            import_counter.connect (
                (count) => {
                    Idle.add (
                        () => {
                            this.badge = count.to_string ();
                            return false;
                        });
                });
        }

        public NavigationExternalDevice (Objects.ExternalDevice device) {
            this.device = device;
            this.name = device.volume.get_name ();
            this.icon = device.volume.get_icon ();
            album = new Objects.Album (this.name);

            this.device.pictures_found.connect (
                (uri) => {
                    Idle.add (
                        () => {
                            this.badge = device.pictures.length ().to_string ();
                            return false;
                        });
                    add_picture (uri);
                });

            this.badge = device.pictures.length ().to_string ();
            build_menu ();

            foreach (string picture in device.pictures) {
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
            var import_items = new Gtk.MenuItem.with_label (_ ("Import Pictures"));
            import_items.activate.connect (
                () => {
                    import_started ();
                    new Thread<void*> (
                        "import_pictures",
                        () => {
                            uint counter = 0;
                            foreach (var picture in album.pictures) {
                                library_manager.import_from_external_device (picture);
                                counter++;
                                import_counter (counter);
                            }
                            import_finished ();
                            return null;
                        });
                });
            menu.add (import_items);
            menu.show_all ();
        }

        public override Gtk.Menu ? get_context_menu () {
            return menu;
        }
    }
}
