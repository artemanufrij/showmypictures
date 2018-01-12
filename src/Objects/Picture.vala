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
    public class Picture : GLib.Object {

        public signal void preview_created ();
        public signal void removed ();
        public signal void file_not_found ();

        int _ID = 0;
        public int ID {
            get {
                return _ID;
            } set {
                _ID = value;
                if (ID > 0) {
                    preview_path = GLib.Path.build_filename (ShowMyPicturesApp.instance.PREVIEW_FOLDER, ("picture_%d.png").printf (this.ID));
                }
            }
        }

        public string preview_path { get; private set; default = ""; }

        string _path = "";
        public string path {
            get {
                return _path;
            } set {
                _path = value;
                if (ID == 0) {
                    exclude_exif ();
                    if (year == 0) {
                        exclude_creation_date ();
                    }
                    calculate_hash ();
                }
            }
        }

        public string mime_type { get; set; default = ""; }
        public int year { get; set; default = 0; }
        public int month { get; set; default = 0; }
        public int day { get; set; default = 0; }
        public int rotation { get; private set; default = 1; }

        public string keywords { get; set; default = ""; }
        public string comment { get; set; default = ""; }
        public string hash { get; set; default = ""; }

        public Album? album { get; set; default = null; }

        Gdk.Pixbuf? _preview = null;
        public Gdk.Pixbuf? preview {
            get {
                return _preview;
            } private set {
                if (_preview != value) {
                    _preview = value;
                }
                if (_preview != null) {
                    preview_created ();
                }
            }
        }

        public Exif.Data? exif_data { get; private set; default = null; }

        bool preview_creating = false;
        bool exif_excluded = false;

        construct {
            removed.connect (() => {
                if (album != null) {
                    album.picture_removed (this);
                }
                var f = File.new_for_path (path);
                f.trash_async.begin ();
                f.dispose ();
            });
        }

        public Picture (Album? album = null) {
            this.album = album;
        }

        public async void create_preview_async () {
            if (preview_creating) {
                return;
            }
            new Thread<void*> (null, () => {
                create_preview ();
                return null;
            });
        }

        public void create_preview () {
            preview_creating = true;

            if (preview != null) {
                preview_creating = false;
                return;
            }

            if (GLib.FileUtils.test (preview_path, GLib.FileTest.EXISTS)) {
                try {
                    preview = new Gdk.Pixbuf.from_file (preview_path);
                } catch (Error err) {
                    warning (err.message);
                }
            }
            if (preview != null) {
                preview_creating = false;
                return;
            }
            try {
                var pixbuf = new Gdk.Pixbuf.from_file (path);
                exclude_exif ();
                pixbuf = pixbuf.rotate_simple (Utils.get_rotation (this));
                pixbuf = Utils.align_and_scale_pixbuf_for_preview (pixbuf);
                pixbuf.save (preview_path, "png");
                preview = pixbuf;
                pixbuf.dispose ();
            } catch (Error err) {
                warning (err.message);
            }
            preview_creating = false;
        }

        public void exclude_exif () {
            if (exif_excluded) {
                return;
            }
            if (!file_exists ()) {
                return;
            }
            if (exif_data == null) {
                exif_data = Exif.Data.new_from_file (path);
            }
            if (exif_data == null) {
                return;
            }
            exif_data.foreach_content ((content, user) => {
                if (content == null) {
                    return;
                }

                var entry_date_time = content.get_entry (Exif.Tag.DATE_TIME_ORIGINAL);
                if (entry_date_time != null) {
                    var tag_string = entry_date_time.get_string ();
                    if (tag_string == null || tag_string.strip () == "") {
                        return;
                    }
                    var date_string = tag_string.split (" ")[0];
                    Date date = {};
                    date.set_parse (date_string);
                    if (date.valid ()) {
                        (user as Objects.Picture).year = date.get_year ();
                        (user as Objects.Picture).month = date.get_month ();
                        (user as Objects.Picture).day = date.get_day ();
                    }
                    date.clear ();
                }

                var entry_orientation = content.get_entry (Exif.Tag.ORIENTATION);
                if (entry_orientation != null) {
                    (user as Objects.Picture).rotation = Exif.Convert.get_short (entry_orientation.data, Exif.ByteOrder.INTEL);
                }
            }, this);
        }

        public bool rotate_left_exif () {
            if (exif_data == null) {
                exif_data = Exif.Data.new_from_file (path);
            }
            exif_data.foreach_content ((content, user) => {
                content.foreach_entry ((entry, user) => {
                    if (entry.tag == Exif.Tag.ORIENTATION) {
                    stdout.printf ("%d\n", (user as Objects.Picture).rotation);
                        switch ((user as Objects.Picture).rotation) {
                            case 1:
                                Exif.Convert.set_short (entry.data, Exif.ByteOrder.INTEL, 6);
                                (user as Objects.Picture).exif_data.save_data (&entry.data, &entry.size);
                                break;
                            case 6:
                                Exif.Convert.set_short (entry.data, Exif.ByteOrder.INTEL, 3);
                                (user as Objects.Picture).exif_data.save_data (&entry.data, &entry.size);
                                break;
                            case 3:
                                Exif.Convert.set_short (entry.data, Exif.ByteOrder.INTEL, 8);
                                (user as Objects.Picture).exif_data.save_data (&entry.data, &entry.size);
                                break;
                            case 8:
                                Exif.Convert.set_short (entry.data, Exif.ByteOrder.INTEL, 1);
                                (user as Objects.Picture).exif_data.save_data (&entry.data, &entry.size);
                                break;
                        }
                    }
                }, user);
            }, this);

            return false;
        }

        private void exclude_creation_date () {
            if (!file_exists ()) {
                return;
            }
            var f = File.new_for_path (path);
            var info = f.query_info ("time::*", 0);
            f.dispose ();
            var output = info.get_attribute_as_string (FileAttribute.TIME_CREATED);
            if (output == null) {
                output = info.get_attribute_as_string (FileAttribute.TIME_MODIFIED);
            }
            info.dispose ();

            if (output != null && output != "") {
                var date = new DateTime.from_unix_local (int64.parse (output));
                year = date.get_year ();
                month = date.get_month ();
                day = date.get_day_of_month ();
                date = null;
            }
        }

        private void calculate_hash () {
            Checksum checksum = new Checksum (ChecksumType.MD5);
            FileStream stream = FileStream.open (path, "r");
            uint8 fbuf[100];
            size_t size;
            while ((size = stream.read (fbuf)) > 0) {
                checksum.update (fbuf, size);
            }
            hash = checksum.get_string ();
        }

        public bool file_exists () {
            bool return_value = true;
            var file = File.new_for_path (this.path);
            if (!file.query_exists ()) {
                file_not_found ();
                return_value = false;
            }
            file.dispose ();
            return return_value;
        }
    }
}
