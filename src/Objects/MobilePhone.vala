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
    public class MobilePhone : GLib.Object {
        public Volume volume { get; private set; }

        public signal void copy_started ();
        public signal void copy_finished ();
        public signal void copy_progress (string title, uint count, uint sum);
        public signal void pictures_found (uint count);

        public uint64 size { get; private set; }
        public uint64 free { get; private set; }

        public unowned GLib.List<string> pictures { get; private set; }

        construct {
            pictures = new GLib.List<string> ();
        }

        public MobilePhone (Volume volume) {
            this.volume = volume;
            if (this.volume.get_mount () == null) {
                this.volume.mount.begin (
                    MountMountFlags.NONE,
                    null,
                    null,
                    (obj, res) => {
                        found_pictures_folder (volume.get_activation_root ().get_uri ());
                    });
            } else {
                found_pictures_folder (volume.get_activation_root ().get_uri ());
            }
        }

        private void found_pictures_folder (string uri) {
            new Thread <void*> (
                "found_pictures_folder",
                () => {
                    var file = File.new_for_uri (uri);
                    try {
                        var children = file.enumerate_children ("standard::*", GLib.FileQueryInfoFlags.NONE);
                        FileInfo file_info = null;
                        while ((file_info = children.next_file ()) != null) {
                            if (file_info.get_file_type () == FileType.DIRECTORY) {
                                if (file_info.get_name ().down () == "pictures") {
                                    extract_picture_files (uri + file_info.get_name () + "/");
                                    break;
                                } else {
                                    found_pictures_folder (uri + file_info.get_name () + "/");
                                }
                            }
                        }
                    } catch (Error err) {
                        warning (err.message);
                    }
                    return null;
                });
        }

        private void extract_picture_files (string uri) {
            var file = File.new_for_uri (uri);
            try {
                var children = file.enumerate_children ("standard::*", GLib.FileQueryInfoFlags.NONE);
                FileInfo file_info = null;
                while ((file_info = children.next_file ()) != null) {
                    if (file_info.get_file_type () == FileType.DIRECTORY) {
                        extract_picture_files (uri + file_info.get_name () + "/");
                        continue;
                    }

                    var exception_check = file_info.get_name ().down ();

                    if (exception_check.has_suffix ("jpg") || exception_check.has_suffix ("png")) {
                        pictures.append (uri + file_info.get_name ());
                        pictures_found (pictures.length ());
                    }
                }
            } catch (Error err) {
                warning (err.message);
            }
        }
    }
}
