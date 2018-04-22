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
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
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
        public signal void request_rename ();

        Gtk.Label title;
        Gtk.Label date_size_resolution;
        Gtk.Label location;
        Gtk.Entry keywords_entry;
        Gtk.ScrolledWindow comment_scroll;
        Gtk.TextView comment_entry;
        Gtk.Box navigation_controls;
        Gtk.Box controls;

        Gtk.Button go_next;
        Gtk.Button go_prev;
        Gtk.Button rotate_left;
        Gtk.Button rotate_right;
        Gtk.Button into_trash;
        Gtk.Button rename;

        Gtk.Label lab_details;

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

            controls = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);
            controls.margin = 12;
            rotate_left = new Gtk.Button.from_icon_name ("object-rotate-left-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
            rotate_left.tooltip_text = _ ("Rotate left [Ctrl+Left]");
            rotate_left.valign = Gtk.Align.CENTER;
            rotate_left.clicked.connect (
                () => {
                    current_picture.rotate_left_exiv ();
                });
            rotate_right = new Gtk.Button.from_icon_name ("object-rotate-right-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
            rotate_right.tooltip_text = _ ("Rotate right [Ctrl+Right]");
            rotate_right.valign = Gtk.Align.CENTER;
            rotate_right.clicked.connect (
                () => {
                    current_picture.rotate_right_exiv ();
                });


            into_trash = new Gtk.Button.from_icon_name ("edit-delete-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
            into_trash.tooltip_text = _ ("Move into trash");
            into_trash.valign = Gtk.Align.CENTER;
            into_trash.clicked.connect (
                () => {
                    db_manager.remove_picture (current_picture);
                });

            rename = new Gtk.Button.from_icon_name ("document-edit-symbolic", Gtk.IconSize.SMALL_TOOLBAR);
            rename.tooltip_text = _ ("Rename current Picture");
            rename.valign = Gtk.Align.CENTER;
            rename.clicked.connect (
                () => {
                    request_rename ();
                });

            navigation_controls = new Gtk.Box (Gtk.Orientation.HORIZONTAL, 6);

            go_next = new Gtk.Button.from_icon_name ("go-next-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            go_next.tooltip_text = _ ("Next Picture");
            go_next.valign = Gtk.Align.CENTER;
            go_next.clicked.connect (
                () => {
                    next ();
                });
            go_prev = new Gtk.Button.from_icon_name ("go-previous-symbolic", Gtk.IconSize.LARGE_TOOLBAR);
            go_prev.tooltip_text = _ ("Previous Picture");
            go_prev.valign = Gtk.Align.CENTER;
            go_prev.clicked.connect (
                () => {
                    prev ();
                });
            navigation_controls.pack_start (go_prev, false, false);
            navigation_controls.pack_start (go_next, false, false);

            controls.pack_start (into_trash, false, false);
            controls.pack_start (rename, false, false);
            controls.set_center_widget (navigation_controls);
            controls.pack_end (rotate_right, false, false);
            controls.pack_end (rotate_left, false, false);

            var scroll = new Gtk.ScrolledWindow (null, null);
            scroll.set_size_request (256, -1);

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

            comment_scroll = new Gtk.ScrolledWindow (null, null);
            comment_scroll.height_request = 64;
            comment_entry = new Gtk.TextView ();
            comment_entry.buffer.text = "";
            comment_scroll.add (comment_entry);

            lab_details = new Gtk.Label ("");

            location = new Gtk.Label ("");
            location.xalign = 0;
            location.wrap = true;
            location.wrap_mode = Pango.WrapMode.WORD_CHAR;
            location.selectable = true;

            box.pack_start (date_size_resolution, false, false);
            box.pack_start (keywords_entry, false, false);
            box.pack_start (comment_scroll, false, false);
            box.pack_start (lab_details, false, false);
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

            if (current_picture != null) {
                current_picture.updated.disconnect (picture_updated);
            }

            current_picture = picture;

            if (current_picture.date == null) {
                current_picture.exclude_creation_date ();
            }
            if (current_picture.width > 0 && current_picture.height > 0) {
                date_size_resolution.label = "%s\n%d × %d".printf (current_picture.date, current_picture.width, current_picture.height);
                date_size_resolution.show ();
            } else {
                date_size_resolution.hide ();
            }
            location.label = Uri.unescape_string (current_picture.file.get_uri ());

            if (picture.source_type == Objects.SourceType.LIBRARY) {
                keywords_entry.text = current_picture.keywords;
                comment_entry.buffer.text = current_picture.comment;

                comment_scroll.show ();
                keywords_entry.show ();
            } else {
                comment_scroll.hide ();
                keywords_entry.hide ();
            }

            show_camera_details ();

            if (picture.source_type == Objects.SourceType.MTP) {
                hide_all_controls ();
            } else {
                show_all_controls ();
            }

            current_picture.updated.connect (picture_updated);
        }

        private void show_camera_details () {
            if (current_picture.iso_speed > 0) {
                var nom = current_picture.exposure_time_nom;
                var den = current_picture.exposure_time_den;
                var exposure = "%d/%ds".printf (nom, den);
                if (nom > 1) {
                    if (nom % den == 0) {
                        exposure = "%.f\"".printf ((double)nom / den);
                    } else {
                        exposure = "%.1f\"".printf ((double)nom / den);
                    }
                } else if (den <= 3) {
                    exposure = "%.1f\"".printf ((double)nom / den);
                }

                lab_details.label= "ISO: %d | f: %.1f | %s | %.0fmm".printf (
                    current_picture.iso_speed,
                    current_picture.fnumber,
                    exposure,
                    current_picture.focal_length);
                lab_details.show ();
            } else {
                lab_details.hide ();
            }
        }

        private void picture_updated () {
            location.label = Uri.unescape_string (current_picture.file.get_uri ());
        }

        public void save_changes () {
            if (current_picture == null || current_picture.ID == 0) {
                return;
            }
            bool keywords_changed = current_picture.keywords != keywords_entry.text.strip ();
            bool comment_changed = current_picture.comment != comment_entry.buffer.text.strip ();

            if (keywords_changed || comment_changed) {
                current_picture.keywords = Utils.format_keywords (keywords_entry.text.strip ());
                current_picture.comment = comment_entry.buffer.text.strip ();
                current_picture.colors = "";
                current_picture.stars = 0;

                db_manager.update_picture (current_picture);
                if (keywords_changed) {
                    db_manager.keywords_changed ();
                }
            }
        }

        public void hide_controls () {
            go_next.hide ();
            go_prev.hide ();
            rotate_left.hide ();
            rotate_right.hide ();
        }

        private void hide_all_controls () {
            controls.hide ();
        }

        private void show_all_controls () {
            controls.show ();
        }
    }
}