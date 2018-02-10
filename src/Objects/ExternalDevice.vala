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

namespace ShowMyPictures.Objects {
    public class ExternalDevice : GLib.Object {
        public Volume volume { get; protected set; }

        public signal void pictures_found (string uri);

        public unowned GLib.List<string> pictures { get; protected set; }

        construct {
            pictures = new GLib.List<string> ();
        }

        public ExternalDevice (Volume volume) {
            this.volume = volume;
        }

        protected void extract_picture_files (string uri) {
            string folder = uri;
            if (!folder.has_suffix ("/")) {
                folder += "/";
            }
            new Thread <void*> (
                "extract_picture_files",
                () => {
                    File file = null;
                    if (folder.has_prefix ("/")) {
                        file = File.new_for_path (folder);
                    } else {
                        file = File.new_for_uri (folder);
                    }

                    try {
                        var children = file.enumerate_children ("standard::*", GLib.FileQueryInfoFlags.NONE);
                        FileInfo file_info = null;
                        while ((file_info = children.next_file ()) != null) {
                            if (file_info.get_file_type () == FileType.DIRECTORY) {
                                extract_picture_files (folder + file_info.get_name () + "/");
                                continue;
                            }

                            if (Utils.is_valid_extention (file_info.get_name ().down ())) {
                                pictures.append (folder + file_info.get_name ());
                                pictures_found (folder + file_info.get_name ());
                            }
                        }
                    } catch (Error err) {
                        warning (err.message);
                    }
                    return null;
                });
        }
    }
}