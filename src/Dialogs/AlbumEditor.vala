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

namespace ShowMyPictures.Dialogs {
    public class AlbumEditor : Gtk.Dialog {
        Services.LibraryManager library_manager;
        Services.DataBaseManager db_manager;
        Settings settings;
        Objects.Album album;

        Gtk.Image cover;
        Gtk.Entry title_entry;
        Gtk.Entry keywords_entry;
        Gtk.TextView comment_entry;

        construct {
            library_manager = Services.LibraryManager.instance;
            db_manager = Services.DataBaseManager.instance;
            settings = Settings.get_default ();
        }

        public AlbumEditor (Gtk.Window parent, Objects.Album album) {
            Object (transient_for: parent);
            this.album = album;
            build_ui ();

            this.response.connect (
                (source, response_id) => {
                    switch (response_id) {
                    case Gtk.ResponseType.ACCEPT :
                        save ();
                        break;
                    }
                });
            this.key_press_event.connect (
                (event) => {
                    if ((event.keyval == Gdk.Key.Return || event.keyval == Gdk.Key.KP_Enter) && Gdk.ModifierType.CONTROL_MASK in event.state) {
                        save ();
                    }
                    return false;
                });
        }

        private void build_ui () {
            this.resizable = false;
            var content = get_content_area () as Gtk.Box;

            var grid = new Gtk.Grid ();
            grid.column_spacing = 12;
            grid.row_spacing = 12;
            grid.margin = 12;

            var event_box = new Gtk.EventBox ();

            cover = new Gtk.Image ();
            if (album.cover == null) {
                cover.set_from_icon_name ("picture-x-generic-symbolic", Gtk.IconSize.DIALOG);
                cover.height_request = 256;
                cover.width_request = 256;
            } else {
                cover.pixbuf = album.cover;
            }

            event_box.add (cover);

            title_entry = new Gtk.Entry ();
            title_entry.get_style_context ().add_class ("h3");
            title_entry.text = album.title;

            var keywords_label = new Gtk.Label (_ ("Keywords"));
            keywords_entry = new Gtk.Entry ();
            keywords_entry.text = album.keywords;

            var comment_scroll = new Gtk.ScrolledWindow (null, null);
            comment_scroll.height_request = 64;
            comment_entry = new Gtk.TextView ();
            comment_entry.buffer.text = album.comment;
            comment_scroll.add (comment_entry);

            grid.attach (event_box, 0, 0, 2, 1);
            grid.attach (title_entry, 0, 1, 2, 1);
            grid.attach (keywords_label, 0, 2);
            grid.attach (keywords_entry, 1, 2);
            grid.attach (comment_scroll, 0, 3, 2, 1);

            content.pack_start (grid, false, false, 0);

            var save_button = this.add_button (_ ("Save"), Gtk.ResponseType.ACCEPT) as Gtk.Button;
            save_button.get_style_context ().add_class (Gtk.STYLE_CLASS_SUGGESTED_ACTION);
            this.show_all ();
        }

        private void save () {
            album.title = title_entry.text.strip ();

            bool keywords_changed = album.keywords != keywords_entry.text.strip ();

            album.keywords = Utils.format_keywords (keywords_entry.text.strip ());
            album.comment = comment_entry.buffer.text.strip ();
            db_manager.update_album (album);
            if (keywords_changed) {
                db_manager.keywords_changed ();
            }
            this.destroy ();
        }
    }
}
