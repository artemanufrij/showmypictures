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

        public signal void merge ();

        Gtk.Image cover;
        Gtk.Label counter;
        Gtk.Label title;
        Gtk.Menu menu;
        Gtk.MenuItem menu_merge;
        Gtk.Image add_selection_image;
        Gtk.Image multi_selected_image;
        Gtk.Button multi_select;

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
            event_box.enter_notify_event.connect (
                (event) => {
                    multi_select.opacity = 1;
                    return false;
                });
            event_box.leave_notify_event.connect (
                (event) => {
                    if (!this.is_selected ()) {
                        multi_select.opacity = 0;
                    }
                    return false;
                });

            var content = new Gtk.Grid ();
            content.halign = Gtk.Align.CENTER;
            content.row_spacing = 6;
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

            menu = new Gtk.Menu ();
            var menu_new_cover = new Gtk.MenuItem.with_label (_ ("Edit Album properties…"));
            menu_new_cover.activate.connect (
                () => {
                    edit_album ();
                });
            menu.add (menu_new_cover);

            menu_merge = new Gtk.MenuItem.with_label (_ ("Merge selected Artists"));
            menu_merge.activate.connect (() => {
                                             merge ();
                                         });
            menu.add (menu_merge);

            menu.show_all ();

            // MULTISELECTION BUTTON
            add_selection_image = new Gtk.Image.from_icon_name ("selection-add", Gtk.IconSize.BUTTON);
            multi_selected_image = new Gtk.Image.from_icon_name ("selection-checked", Gtk.IconSize.BUTTON);

            multi_select = new Gtk.Button ();
            multi_select.valign = Gtk.Align.START;
            multi_select.halign = Gtk.Align.START;
            multi_select.get_style_context ().remove_class ("button");
            multi_select.set_image (add_selection_image);
            multi_select.can_focus = false;
            multi_select.opacity = 0;
            multi_select.clicked.connect (
                () => {
                    toggle_multi_selection ();
                });
            multi_select.enter_notify_event.connect (
                (event) => {
                    multi_select.opacity = 1;
                    return false;
                });

            content.attach (multi_select, 0, 0);
            content.attach (cover, 0, 0);
            content.attach (title, 0, 1);
            content.attach (counter, 0, 2);

            this.add (event_box);
            this.show_all ();
        }

        public void toggle_multi_selection (bool activate = true) {
            if (!multi_selection) {
                multi_selection = true;
                if (activate) {
                    this.activate ();
                }
                multi_select.opacity = 1;
                multi_select.set_image (multi_selected_image);
            } else {
                multi_selection = false;
                (this.parent as Gtk.FlowBox).unselect_child (this);
                multi_select.set_image (add_selection_image);
            }
        }

        private bool show_context_menu (Gtk.Widget sender, Gdk.EventButton evt) {
            if (evt.type == Gdk.EventType.BUTTON_PRESS && evt.button == 3) {
                (this.parent as Gtk.FlowBox).select_child (this);

                // MERGE
                if ((this.parent as Gtk.FlowBox).get_selected_children ().length () > 1) {
                    menu_merge.show_all ();
                } else {
                    menu_merge.hide ();
                }

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

        public void reset () {
            multi_select.set_image (add_selection_image);
            multi_select.opacity = 0;
            multi_selection = false;
        }
    }
}
