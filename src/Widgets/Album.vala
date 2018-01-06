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
    public class Album : Gtk.FlowBoxChild {

        public Objects.Album album { get; private set; }

        Gtk.Image cover;
        Gtk.Label counter;
        Gtk.Label title;
        Gtk.Menu menu;

        public int year { get { return album.year; } }
        public int month { get { return album.month; } }
        public int day { get { return album.day; } }

        public Album (Objects.Album album) {
            this.album = album;

            build_ui ();

            this.album.notify["title"].connect (() => {
                title.label = this.album.title;
            });
        }

        private void build_ui () {
            var event_box = new Gtk.EventBox ();
            event_box.button_press_event.connect (show_context_menu);

            var content = new Gtk.Grid ();
            content.halign = Gtk.Align.CENTER;
            content.row_spacing = 6;
            content.margin = 12;
            content.get_style_context ().add_class ("album");
            content.get_style_context ().add_class ("card");
            event_box.add (content);

            cover = new Gtk.Image ();
            album.cover_created.connect (() => {
                Idle.add (() => {
                    cover.pixbuf = this.album.cover;
                    return false;
                });
            });
            cover.pixbuf = album.cover;
            cover.margin = 6;

            title = new Gtk.Label (album.title);
            title.get_style_context ().add_class ("h3");
            counter = new Gtk.Label (_("%u Pictures").printf (album.pictures.length ()));
            album.picture_added.connect ((picture) => {
                Idle.add (() => {
                    counter.label = _("%u Pictures").printf (album.pictures.length ());
                    return false;
                });
            });
            counter.margin_bottom = 6;

            menu = new Gtk.Menu ();
            var menu_new_cover = new Gtk.MenuItem.with_label (_("Edit Album properties…"));
            menu_new_cover.activate.connect (() => {
                edit_album ();
            });
            menu.add (menu_new_cover);
            menu.show_all ();

            content.attach (cover, 0, 0);
            content.attach (title, 0, 1);
            content.attach (counter, 0, 2);

            this.add (event_box);
            this.show_all ();
        }

        private bool show_context_menu (Gtk.Widget sender, Gdk.EventButton evt) {
            if (evt.type == Gdk.EventType.BUTTON_PRESS && evt.button == 3) {
                (this.parent as Gtk.FlowBox).select_child (this);
                menu.popup (null, null, null, evt.button, evt.time);
                return true;
            }
            return false;
        }

        private void edit_album () {
            var editor = new Dialogs.AlbumEditor (ShowMyPicturesApp.instance.mainwindow, this.album);
            if (editor.run () == Gtk.ResponseType.ACCEPT) {
                editor.destroy ();
            }
        }
    }
}
