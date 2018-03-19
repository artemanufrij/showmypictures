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

namespace ShowMyPictures.Utils {
    public static Gtk.Menu create_picture_menu (Objects.Picture picture) {
        Gtk.Menu menu = new Gtk.Menu ();

        var menu_open_with = new Gtk.MenuItem.with_label (_ ("Open with"));
        menu_open_with.name = "open_with";
        var open_with = new Gtk.Menu ();
        menu_open_with.set_submenu (open_with);
        menu.add (menu_open_with);

        if (picture.source_type == Objects.SourceType.LIBRARY) {
            var menu_new_cover = new Gtk.MenuItem.with_label (_ ("Set as Album picture"));
            menu_new_cover.activate.connect (
                () => {
                    picture.album.set_new_cover_from_picture (picture);
                    ShowMyPicturesApp.instance.mainwindow.send_app_notification (_ ("Album cover changed"));
                });
            menu.add (menu_new_cover);
            menu.add (new Gtk.SeparatorMenuItem ());
        }

        var menu_open_loacation = new Gtk.MenuItem.with_label (_ ("Open location"));
        menu_open_loacation.activate.connect (
            () => {
                var folder = Path.get_dirname (picture.file.get_uri ());
                try {
                    Process.spawn_command_line_async ("xdg-open '%s'".printf (folder));
                } catch (Error err) {
                                warning (err.message);
                }
            });
        menu.add (menu_open_loacation);

        if (picture.source_type != Objects.SourceType.MTP && picture.source_type != Objects.SourceType.GPHOTO) {
            var menu_move_into_trash = new Gtk.MenuItem.with_label (_ ("Move into Trash"));
            menu_move_into_trash.activate.connect (
                () => {
                    Services.LibraryManager.instance.db_manager.remove_picture (picture);
                });
            menu.add (menu_move_into_trash);
        }

        var menu_import = new Gtk.MenuItem.with_label ("");
        menu_import.name = "import";
        menu_import.activate.connect (
            () => {
                picture.import_request ();
            });
        menu.add (menu_import);

        menu.show_all ();
        return menu;
    }

    public static void show_picture_menu (Gtk.Menu menu, Objects.Picture picture, uint count = 1) {
        foreach (var item in menu.get_children ()) {
            if (!(item is Gtk.MenuItem)) {
                continue;
            }

            if ((item as Gtk.MenuItem).name == "open_with") {
                Gtk.Menu open_with = (item as Gtk.MenuItem).get_submenu () as Gtk.Menu;
                foreach (var child in open_with.get_children ()) {
                    child.destroy ();
                }

                foreach (var appinfo in AppInfo.get_all_for_type (picture.mime_type)) {
                    if (!Settings.get_default ().use_fastview && appinfo.get_executable () == ShowMyPicturesApp.instance.application_id) {
                        continue;
                    }

                    var menuitem_grid = new Gtk.Grid ();
                    menuitem_grid.margin = 0;
                    menuitem_grid.add (new Gtk.Image.from_gicon (appinfo.get_icon (), Gtk.IconSize.MENU));
                    menuitem_grid.add (new Gtk.Label (appinfo.get_name ()));

                    var open_item = new Gtk.MenuItem ();
                    open_item.get_style_context ().add_class ("menuitem-with-icon");
                    open_item.add (menuitem_grid);
                    open_item.activate.connect (
                        () => {
                            GLib.List<File> files = new GLib.List<File> ();
                            files.append (picture.file);
                            try {
                                appinfo.launch (files, null);
                            } catch (Error err) {
                                warning (err.message);
                            }
                        });
                    open_with.add (open_item);
                }
                open_with.show_all ();
            }

            if ((item as Gtk.MenuItem).name == "import") {
                Gtk.MenuItem menu_import = (item as Gtk.MenuItem);
                if (picture.source_type != Objects.SourceType.LIBRARY) {
                    if (count == 1) {
                        menu_import.label = _ ("Import");
                    } else {
                        menu_import.label = _ ("Import %u pictures").printf (count);
                    }
                    menu_import.show ();
                } else {
                    menu_import.hide ();
                }
            }
        }
    }

    public static Gtk.Menu create_album_menu (Objects.Album album) {
        Gtk.Menu menu = new Gtk.Menu ();
        var menu_new_cover = new Gtk.MenuItem.with_label (_ ("Edit Album properties…"));
        menu_new_cover.activate.connect (
            () => {
                album.edit_request ();
            });
        menu.add (menu_new_cover);

        var menu_optimize = new Gtk.MenuItem.with_label (_ ("Optimize pictures (lossless)"));
        menu_optimize.activate.connect (
            () => {
                album.optimize ();
            });
        menu.add (menu_optimize);

        var menu_merge = new Gtk.MenuItem.with_label ("");
        menu_merge.name = "merge_placeholder";
        menu_merge.activate.connect (
            () => {
                album.merge_request ();
            });
        menu.add (menu_merge);
        menu.show_all ();

        return menu;
    }

    public static void show_album_menu (Gtk.Menu menu, uint merge_counter) {
        foreach (var item in menu.get_children ()) {
            if ((item is Gtk.MenuItem) && (item as Gtk.MenuItem).name == "merge_placeholder") {
                Gtk.MenuItem menu_merge = (item as Gtk.MenuItem);
                if (merge_counter > 1) {
                    menu_merge.label = _ ("Merge %u selected Albums").printf (merge_counter);
                    menu_merge.show_all ();
                } else {
                    menu_merge.hide ();
                }
                return;
            }
        }
    }
}