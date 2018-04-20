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

namespace ShowMyPictures.Widgets {
    public class Album : Gtk.FlowBoxChild {
        public Objects.Album album { get; private set; }

        public signal void context_opening ();

        Gtk.Image cover;
        Gtk.Label counter;
        Gtk.Label title;
        Gtk.Label saved_size;
        Gtk.Menu menu = null;

        Gtk.Spinner spinner;

        public int year { get { return album.year; } }
        public int month { get { return album.month; } }
        public int day { get { return album.day; } }

        public bool multi_selection { get; private set; default = false; }

        public Album (Objects.Album album) {
            this.album = album;
            this.draw.connect (first_draw);
            build_ui ();
            this.album.notify["title"].connect (
                () => {
                    title.label = this.album.title;
                });
            this.album.removed.connect (
                () => {
                    Idle.add (
                        () => {
                            this.destroy ();
                            return false;
                        });
                });
            this.album.cover_created.connect (
                () => {
                    Idle.add (
                        () => {
                            cover.pixbuf = this.album.cover;
                            return false;
                        });
                });
            this.album.picture_added.connect (
                (picture, new_count) => {
                    Idle.add (
                        () => {
                            counter.label = _ ("%u Pictures").printf (new_count);
                            return false;
                        });
                });
            this.album.picture_removed.connect (
                (picture) => {
                    Idle.add (
                        () => {
                            counter.label = _ ("%u Pictures").printf (this.album.pictures.length ());
                            return false;
                        });
                });
            this.album.optimize_started.connect (
                () => {
                    spinner.active = true;
                });
            this.album.optimize_ended.connect (
                () => {
                    spinner.active = false;
                });
            this.album.optimize_progress.connect (
                (saved) => {
                    Idle.add (
                        () => {
                            saved_size.label = "<small>%s</small>".printf (Utils.format_saved_size (saved));
                            return false;
                        });
                });
            this.album.edit_request.connect (edit_album);
            this.album.updated.connect (set_tooltip);
        }

        private bool first_draw () {
            this.draw.disconnect (first_draw);
            if (album.cover != null) {
                cover.pixbuf = album.cover;
            } else {
                cover.set_from_icon_name ("image-x-generic-symbolic", Gtk.IconSize.DIALOG);
            }
            counter.label = _ ("%u Pictures").printf (album.pictures.length ());
            return false;
        }

        private void build_ui () {
            var event_box = new Gtk.EventBox ();
            event_box.button_press_event.connect (show_context_menu);

            var content = new Gtk.Grid ();
            content.halign = Gtk.Align.CENTER;
            content.row_spacing = 6;
            content.column_homogeneous = true;
            content.margin = 12;
            content.get_style_context ().add_class ("album");
            content.get_style_context ().add_class ("card");
            event_box.add (content);

            cover = new Gtk.Image ();
            cover.margin = 6;
            cover.height_request = 240;
            cover.width_request = 240;

            title = new Gtk.Label (album.title);
            title.get_style_context ().add_class ("h3");

            counter = new Gtk.Label ("");
            counter.margin_bottom = 6;
            counter.halign = Gtk.Align.CENTER;

            spinner = new Gtk.Spinner ();
            spinner.halign = Gtk.Align.START;
            spinner.margin_bottom = 6;
            spinner.margin_left = 6;

            saved_size = new Gtk.Label ("");
            saved_size.halign = Gtk.Align.END;
            saved_size.margin_bottom = 6;
            saved_size.margin_right = 6;
            saved_size.use_markup = true;
            saved_size.valign = Gtk.Align.END;

            content.attach (cover, 0, 0, 3, 1);
            content.attach (title, 0, 1, 3, 1);
            content.attach (spinner, 0, 2);
            content.attach (counter, 1, 2);
            content.attach (saved_size, 2, 2);

            set_tooltip ();

            this.add (event_box);
            this.show_all ();
        }

        public void toggle_multi_selection (bool activate = true) {
            if (!multi_selection) {
                multi_selection = true;
                if (activate) {
                    this.activate ();
                }

            } else {
                multi_selection = false;
                (this.parent as Gtk.FlowBox).unselect_child (this);
            }
        }

        private bool show_context_menu (Gtk.Widget sender, Gdk.EventButton evt) {
            if (evt.type == Gdk.EventType.BUTTON_PRESS && evt.button == 3) {

                if (menu == null) {
                    menu = Utils.create_album_menu (album);
                }

                context_opening ();
                var parent = (this.parent as Gtk.FlowBox);
                parent.select_child (this);

                // MERGE
                var count = parent.get_selected_children ().length ();
                Utils.show_album_menu (menu, count);

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

        private void set_tooltip () {
            var k = _("Keywords:\n<b>%s</b>").printf (album.keywords);

            var c = _("Comments:\n<b>%s</b>").printf (album.comment);

            if (album.keywords != "" && album.comment != "") {
                this.tooltip_markup = k + "\n\n" + c;
            } else if (album.keywords != "") {
                this.tooltip_markup = k;
            } else if (album.comment != "") {
                this.tooltip_markup = c;
            } else {
                this.tooltip_markup = null;
            }
        }

        public void reset () {
            multi_selection = false;
        }
    }
}
