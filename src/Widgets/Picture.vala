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
    public class Picture : Gtk.FlowBoxChild {
        ShowMyPictures.Services.LibraryManager library_manager;

        public Objects.Picture picture { get; private set; }

        Gtk.Image preview;
        Gtk.Menu menu;

        construct {
            library_manager = ShowMyPictures.Services.LibraryManager.instance;
        }

        public Picture (Objects.Picture picture) {
            this.picture = picture;
            this.picture.preview_created.connect (() => {
                Idle.add (() => {
                    preview.pixbuf = this.picture.preview;
                    return false;
                });
            });
            this.picture.removed.connect (() => {
                Idle.add (() => {
                    this.destroy ();
                    return false;
                });
            });
            build_ui ();
        }

        private void build_ui () {
            var event_box = new Gtk.EventBox ();
            event_box.button_press_event.connect (show_context_menu);

            preview = new Gtk.Image ();
            preview.halign = Gtk.Align.CENTER;
            preview.get_style_context ().add_class ("card");
            preview.margin = 12;
            preview.pixbuf = picture.preview;

            event_box.add (preview);

            menu = new Gtk.Menu ();
            var menu_new_cover = new Gtk.MenuItem.with_label (_("Set as Album picture"));
            menu_new_cover.activate.connect (() => {
                picture.album.set_new_cover_from_picture (picture);
            });
            var menu_move_into_trash = new Gtk.MenuItem.with_label (_("Move into Trash"));
            menu_move_into_trash.activate.connect (() => {
                library_manager.db_manager.remove_picture (picture);
            });

            menu.add (menu_new_cover);
            menu.add (menu_move_into_trash);
            menu.show_all ();

            this.add (event_box);
        }

        private bool show_context_menu (Gtk.Widget sender, Gdk.EventButton evt) {
            if (evt.type == Gdk.EventType.BUTTON_PRESS && evt.button == 3) {
                (this.parent as Gtk.FlowBox).select_child (this);
                menu.popup (null, null, null, evt.button, evt.time);
                return true;
            }
            return false;
        }
    }
}
