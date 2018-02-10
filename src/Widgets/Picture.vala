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

        public signal void context_opening ();

        public Objects.Picture picture { get; private set; }

        Gtk.Image preview;
        Gtk.Menu menu = null;

        public bool multi_selection { get; private set; default = false; }

        construct {
            library_manager = ShowMyPictures.Services.LibraryManager.instance;
        }

        public Picture (Objects.Picture picture) {
            this.picture = picture;
            this.draw.connect (first_draw);
            build_ui ();
            this.picture.preview_created.connect (
                () => {
                    Idle.add (
                        () => {
                            preview.pixbuf = this.picture.preview;
                            return false;
                        });
                });
            this.picture.removed.connect (
                () => {
                    Idle.add (
                        () => {
                            this.destroy ();
                            return false;
                        });
                });
        }

        private bool first_draw () {
            this.draw.disconnect (first_draw);
            if (picture.preview != null) {
                preview.pixbuf = picture.preview;
            } else {
                preview.set_from_icon_name ("image-x-generic-symbolic", Gtk.IconSize.DIALOG);
            }
            return false;
        }

        private void build_ui () {
            this.tooltip_text = picture.path;
            var event_box = new Gtk.EventBox ();
            event_box.button_press_event.connect (show_context_menu);

            var content = new Gtk.Grid ();
            content.halign = Gtk.Align.CENTER;
            event_box.add (content);

            preview = new Gtk.Image ();
            preview.halign = Gtk.Align.CENTER;
            preview.get_style_context ().add_class ("card");
            preview.margin = 12;

            content.attach (preview, 0, 0);

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
                    menu = Utils.create_picture_menu (picture);
                }

                var parent = (this.parent as Gtk.FlowBox);
                parent.select_child (this);
                var count = parent.get_selected_children ().length ();

                Utils.show_picture_menu (menu, picture, count);
                (this.parent as Gtk.FlowBox).select_child (this);
                menu.popup (null, null, null, evt.button, evt.time);
                return true;
            }
            return false;
        }
    }
}
