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

    public enum PictureStyle { DEFAULT, NOT_FOUND }

    public class Picture : Gtk.FlowBoxChild {
        ShowMyPictures.Services.LibraryManager library_manager;

        public Objects.Picture picture { get; private set; }
        PictureStyle picture_style;

        Gtk.Image preview;
        Gtk.Menu menu;
        Gtk.Menu open_with;

        construct {
            library_manager = ShowMyPictures.Services.LibraryManager.instance;
        }

        public Picture (Objects.Picture picture, PictureStyle picture_style = PictureStyle.DEFAULT) {
            this.picture_style = picture_style;
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

            menu = new Gtk.Menu ();

            if (picture_style == PictureStyle.DEFAULT) {
                var menu_open_with = new Gtk.MenuItem.with_label (_ ("Open with"));
                open_with = new Gtk.Menu ();
                menu_open_with.set_submenu (open_with);
                menu.add (menu_open_with);

                var menu_new_cover = new Gtk.MenuItem.with_label (_ ("Set as Album picture"));
                menu_new_cover.activate.connect (
                    () => {
                        picture.album.set_new_cover_from_picture (picture);
                        ShowMyPicturesApp.instance.mainwindow.send_app_notification (_ ("Album cover changed"));
                    });
                menu.add (menu_new_cover);
                menu.add (new Gtk.SeparatorMenuItem ());
            }
            var menu_move_into_trash = new Gtk.MenuItem.with_label (_ ("Move into Trash"));
            menu_move_into_trash.activate.connect (
                () => {
                    library_manager.db_manager.remove_picture (picture);
                });

            var menu_open_loacation = new Gtk.MenuItem.with_label (_ ("Open location"));
            menu_open_loacation.activate.connect (
                () => {
                    var folder = Path.get_dirname (picture.path);
                    try {
                        Process.spawn_command_line_async ("xdg-open '%s'".printf (folder));
                    } catch (Error err) {
                                warning (err.message);
                    }
                });

            menu.add (menu_open_loacation);
            menu.add (menu_move_into_trash);
            menu.show_all ();

            this.add (event_box);
            this.show_all ();
        }

        private bool show_context_menu (Gtk.Widget sender, Gdk.EventButton evt) {
            if (evt.type == Gdk.EventType.BUTTON_PRESS && evt.button == 3) {
                if (picture_style == PictureStyle.DEFAULT) {
                    foreach (var child in open_with.get_children ()) {
                        child.destroy ();
                    }

                    var f = File.new_for_path (picture.path);

                    foreach (var appinfo in AppInfo.get_all_for_type (picture.mime_type)) {
                        var item = new Gtk.MenuItem.with_label (appinfo.get_name ());
                        item.activate.connect (
                            () => {
                                GLib.List<File> files = new GLib.List<File> ();
                                files.append (f);
                                try {
                                    appinfo.launch (files, null);
                                } catch (Error err) {
                                    warning (err.message);
                                }
                            });
                        open_with.add (item);
                    }
                    open_with.show_all ();
                }

                (this.parent as Gtk.FlowBox).select_child (this);
                menu.popup (null, null, null, evt.button, evt.time);
                return true;
            }
            return false;
        }
    }
}
