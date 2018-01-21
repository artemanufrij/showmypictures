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
        public signal void updated ();
        public signal void rotated ();
        public signal void file_not_found ();

        int _ID = 0;
        public int ID {
            get {
                return _ID;
            } set {
                _ID = value;
                if (ID > 0) {
                    preview_path = GLib.Path.build_filename (ShowMyPicturesApp.instance.PREVIEW_FOLDER, ("picture_%d.png").printf (this.ID));
                    if (_preview != null) {
                        try {
                            preview.save (preview_path, "png");
                        } catch (Error err) {
                            warning (err.message);
                        }
                    }
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
                    //exclude_exif ();
                    exclude_exiv ();
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
        public int width { get; private set; default = 0; }
        public int height { get; private set; default = 0; }
        public string date { get; private set; default = ""; }

        public string keywords { get; set; default = ""; }
        public string comment { get; set; default = ""; }
        public string hash { get; set; default = ""; }
        public string colors { get; set; default = ""; }
        public int stars { get; set; default = 0; }

        public Album ? album { get; set; default = null; }

        Gdk.Pixbuf ? _preview = null;
        public Gdk.Pixbuf ? preview {
            get {
                if (_preview == null) {
                    create_preview.begin ();
                }
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

        GExiv2.Metadata ? exiv_data = null;

        bool preview_creating = false;
        bool exiv_excluded = false;

        construct {
            removed.connect (
                () => {
                    if (album != null) {
                        album.picture_removed (this);
                    }
                    var f = File.new_for_path (path);
                    f.trash_async.begin ();
                    f.dispose ();

                    f = File.new_for_path (preview_path);
                    f.trash_async.begin ();
                    f.dispose ();
                });
        }

        public Picture (Album ? album = null) {
            this.album = album;
        }

        private async void create_preview () {
            if (preview_creating || _preview != null) {
                return;
            }
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
            if (preview == null && file_exists ()) {
                create_preview_from_path (path);
            }
            preview_creating = false;
        }

        private void create_preview_from_path (string source_path) {
            try {
                var pixbuf = new Gdk.Pixbuf.from_file_at_scale (source_path, -1, 256, true);
                exclude_exiv ();
                var r = Utils.get_rotation (this);
                if (r != Gdk.PixbufRotation.NONE) {
                    pixbuf = pixbuf.rotate_simple (r);
                    pixbuf = Utils.align_and_scale_pixbuf_for_preview (pixbuf);
                }

                if (preview_path != "") {
                    pixbuf.save (preview_path, "png");
                }
                preview = pixbuf;
                pixbuf.dispose ();
                pixbuf = null;
            } catch (Error err) {
                warning (err.message);
            }
        }

        public void exclude_exiv () {
            if (exiv_excluded || !open_exiv ()) {
                return;
            }

            rotation = Utils.Exiv2.convert_rotation_from_exiv (exiv_data.get_orientation ());
            width = exiv_data.get_pixel_width ();
            height = exiv_data.get_pixel_height ();

            date = exiv_data.get_tag_string ("Exif.Photo.DateTimeOriginal");
            if (date != null && date != "") {
                var date_time = Utils.get_datetime_from_string (date);
                if (date_time != null) {
                    year = date_time.get_year ();
                    month = date_time.get_month ();
                    day = date_time.get_day_of_month ();
                    date = date_time.format ("%e. %b, %Y - %T").strip ();
                }
                date_time = null;
            }
            exiv_excluded = true;
        }

        public bool rotate_left_exiv () {
            if (!open_exiv ()) {
                return false;
            }
            exiv_data.set_orientation (Utils.Exiv2.rotate_left (Utils.Exiv2.convert_rotation_to_exiv (rotation)));

            bool saved = false;
            try {
                saved = exiv_data.save_file (path);
            } catch (Error err) {
                warning (err.message);
            }
            if (saved) {
                rotation = Utils.Exiv2.convert_rotation_from_exiv (exiv_data.get_orientation ());
                rotated ();
            }
            return saved;
        }

        public bool rotate_right_exiv () {
            if (!open_exiv ()) {
                return false;
            }
            exiv_data.set_orientation (Utils.Exiv2.rotate_right (Utils.Exiv2.convert_rotation_to_exiv (rotation)));

            bool saved = false;
            try {
                saved = exiv_data.save_file (path);
            } catch (Error err) {
                warning (err.message);
            }
            if (saved) {
                rotation = Utils.Exiv2.convert_rotation_from_exiv (exiv_data.get_orientation ());
                rotated ();
            }
            return saved;
        }

        private bool open_exiv () {
            if (!file_exists ()) {
                return false;
            }
            if (exiv_data == null) {
                exiv_data = new GExiv2.Metadata ();
            }
            if (exiv_data == null) {
                return false;
            }

            try {
                if (!exiv_data.open_path (this.path)) {
                    return false;
                }
            }
            catch (Error err) {
                warning (err.message);
                return false;
            }

            return true;
        }

        public void exclude_creation_date () {
            if (!file_exists ()) {
                return;
            }
            var f = File.new_for_path (path);
            FileInfo info = null;
            try {
                info = f.query_info ("time::*", 0);
            } catch (Error err) {
                warning (err.message);
                return;
            }
            f.dispose ();
            var output = info.get_attribute_as_string (FileAttribute.TIME_CREATED);
            if (output == null) {
                output = info.get_attribute_as_string (FileAttribute.TIME_MODIFIED);
            }
            info.dispose ();

            if (output != null && output != "") {
                var datetime = new DateTime.from_unix_local (int64.parse (output));
                date = datetime.format ("%e. %b, %Y - %T").strip ();
                if (year == 0 || month == 0 || day == 0) {
                    year = datetime.get_year ();
                    month = datetime.get_month ();
                    day = datetime.get_day_of_month ();
                }
                datetime = null;
            }
        }

        private void calculate_hash () {
            Checksum checksum = new Checksum (ChecksumType.MD5);

            checksum.update (path.data, path.length);
            var path_hash = checksum.get_string ();
            var tmp_path = Path.build_filename (Environment.get_tmp_dir (), path_hash + "." + Utils.get_file_extention (path));

            var source_file = File.new_for_path (path);
            var dest_file = File.new_for_path (tmp_path);

            try {
                source_file.copy (dest_file, FileCopyFlags.OVERWRITE);
            } catch (Error err) {
                warning (err.message);
                return;
            }

            checksum = new Checksum (ChecksumType.MD5);

            FileStream stream = FileStream.open (tmp_path, "r");
            uint8 fbuf[100];
            size_t size;
            while ((size = stream.read (fbuf)) > 0) {
                checksum.update (fbuf, size);
            }
            hash = checksum.get_string ();
            new Thread<void*> (
                "calculate_hash",
                () => {
                    create_preview_from_path (tmp_path);
                    try {
                        dest_file.delete ();
                    } catch (Error err) {
                        warning (err.message);
                    }
                    return null;
                });
        }

        public bool file_exists () {
            bool return_value = true;
            if (!GLib.FileUtils.test (path, GLib.FileTest.EXISTS)) {
                file_not_found ();
                return_value = false;
            }
            return return_value;
        }
    }
}
