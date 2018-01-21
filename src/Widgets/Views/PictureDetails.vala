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
    public class PictureDetails : Gtk.Revealer {
        Services.DataBaseManager db_manager;
        Objects.Picture current_picture;

        public signal void next ();
        public signal void prev ();

        Gtk.Label title;
        Gtk.Label date_size_resolution;
        Gtk.Label location;
        Gtk.Entry keywords_entry;
        Gtk.TextView comment_entry;

        public bool has_text_focus {
            get {
                return keywords_entry.is_focus || comment_entry.is_focus;
            }
        }

        construct {
            db_manager = Services.DataBaseManager.instance;
        }

        public PictureDetails () {
            build_ui ();
        }

        private void build_ui () {
            this.transition_type = Gtk.RevealerTransitionType.SLIDE_LEFT;

            var content = new Gtk.Grid ();

            var controls = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            controls.margin = 12;
            var rotate_left = new Gtk.Button.from_icon_name ("object-rotate-left-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
            rotate_left.tooltip_text = _ ("Rotate left");
            rotate_left.valign = Gtk.Align.CENTER;
            rotate_left.clicked.connect (
                () => {
                    current_picture.rotate_left_exiv ();
                });
            var rotate_right = new Gtk.Button.from_icon_name ("object-rotate-right-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
            rotate_right.tooltip_text = _ ("Rotate right");
            rotate_right.valign = Gtk.Align.CENTER;
            rotate_right.clicked.connect (
                () => {
                    current_picture.rotate_right_exiv ();
                });

            var go_next = new Gtk.Button.from_icon_name ("go-next-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            go_next.tooltip_text = _ ("Next Picture");
            go_next.valign = Gtk.Align.CENTER;
            go_next.clicked.connect (
                () => {
                    next ();
                });
            var go_prev = new Gtk.Button.from_icon_name ("go-previous-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            go_prev.tooltip_text = _ ("Previous Picture");
            go_prev.valign = Gtk.Align.CENTER;
            go_prev.clicked.connect (
                () => {
                    prev ();
                });

            controls.pack_start (rotate_left, false, false);
            controls.pack_start (rotate_right, false, false);

            controls.pack_end (go_next, false, false);
            controls.pack_end (go_prev, false, false);

            var scroll = new Gtk.ScrolledWindow (null, null);
            scroll.set_size_request (256,-1);

            var box = new Gtk.Box (Gtk.Orientation.VERTICAL, 12);
            box.margin = 12;

            box.vexpand = true;
            scroll.add (box);

            title = new Gtk.Label ("");
            title.halign = Gtk.Align.START;

            date_size_resolution = new Gtk.Label ("");
            date_size_resolution.halign = Gtk.Align.START;

            keywords_entry = new Gtk.Entry ();
            keywords_entry.placeholder_text = _ ("Keywords comma separated");

            var comment_scroll = new Gtk.ScrolledWindow (null, null);
            comment_scroll.height_request = 64;
            comment_entry = new Gtk.TextView ();
            comment_entry.buffer.text = "";
            comment_scroll.add (comment_entry);

            location = new Gtk.Label ("");
            location.xalign = 0;
            location.wrap = true;
            location.wrap_mode = Pango.WrapMode.WORD_CHAR;

            box.pack_start (date_size_resolution, false, false);
            box.pack_start (keywords_entry, false, false);
            box.pack_start (comment_scroll, false, false);
            box.pack_start (location, false, false);


            content.attach (new Gtk.Separator (Gtk.Orientation.VERTICAL), 0, 0, 1, 2);
            content.attach (controls, 1, 0);
            content.attach (scroll, 1, 1);

            this.add (content);
            this.show_all ();
        }

        public void show_picture (Objects.Picture picture) {
            if (current_picture == picture) {
                return;
            }

            current_picture = picture;

            if (current_picture.date == null) {
                current_picture.exclude_creation_date ();
            }
            date_size_resolution.label = "%s\n%d × %d".printf (current_picture.date, current_picture.width, current_picture.height);
            location.label = current_picture.path;
            keywords_entry.text = current_picture.keywords;
            comment_entry.buffer.text = current_picture.comment;
        }

        public void save_changes () {
            if (current_picture == null) {
                return;
            }
            var new_keywords = keywords_entry.text.strip ();
            var new_comment = comment_entry.buffer.text.strip ();
            if (new_keywords != current_picture.keywords || new_comment != current_picture.comment) {
                current_picture.keywords = new_keywords;
                current_picture.comment = new_comment;
                db_manager.update_picture (current_picture);
            }
        }
    }
}