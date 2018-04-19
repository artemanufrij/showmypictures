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

namespace ShowMyPictures.Popovers {
    public class Rename : Gtk.Popover {
        Objects.Picture current_picture = null;

        string fname = "";
        string fext = "";
        string new_file_name = "";

        Gtk.Entry file_name;

        public Rename () {
            build_ui ();
        }

        private void build_ui () {
            file_name = new Gtk.Entry ();
            file_name.margin = 6;
            file_name.width_request = 260;
            file_name.changed.connect (
                () => {
                    check_file_name ();
                });

            file_name.key_press_event.connect (
                (key) => {
                    switch (key.keyval) {
                    case Gdk.Key.Return :
                        if (check_file_name ()) {
                            current_picture.rename (new_file_name);
                            this.hide ();
                        }
                        break;
                    }
                    return false;
                });

            this.add (file_name);
        }

        public void rename_picture (Objects.Picture picture) {
            current_picture = picture;

            if (current_picture != null) {
                fname = Path.get_basename (current_picture.path);
                fext = "";

                var last_index = fname.last_index_of (".");

                if (last_index > -1) {
                    fext = fname.substring (last_index + 1);
                    fname = fname.substring (0, last_index);
                }

                file_name.text = fname;

                this.show_all ();
            }
        }

        private bool check_file_name () {
            var new_fname = file_name.text.strip ();
            new_file_name = Path.get_dirname (current_picture.path) + "/" + new_fname + "." + fext;

            if (new_fname != "" && FileUtils.test (new_file_name, FileTest.EXISTS)) {
                file_name.secondary_icon_name = "process-error-symbolic";
                file_name.secondary_icon_tooltip_text = _ ("File name exists");
                return false;
            }

            file_name.secondary_icon_name = "process-completed-symbolic";
            file_name.secondary_icon_tooltip_text = _ ("Press [Enter] for rename file");

            return true;
        }
    }
}