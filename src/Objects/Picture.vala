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

namespace ShowMyPictures.Objects {
    public enum SourceType { LIBRARY, GPHOTO, MTP, REMOVABLE, EXTERNAL }

    public class Picture : GLib.Object {
        public signal void preview_created ();
        public signal void removed ();
        public signal void updated ();
        public signal void rotated ();
        public signal void external_modified ();
        public signal void file_not_found ();
        public signal void import_request ();

        public SourceType source_type { get; set; default = SourceType.LIBRARY; }

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
                if (_path.has_prefix ("mtp:")) {
                    source_type = SourceType.MTP;
                } else if (_path.has_prefix ("gphoto2:")) {
                    source_type = SourceType.GPHOTO;
                }
                if (_path.has_prefix ("/")) {
                    file = File.new_for_path (_path);
                } else {
                    file = File.new_for_uri (_path);
                }
                if (ID == 0) {
                    exclude_exiv ();
                    if (year == 0) {
                        exclude_creation_date ();
                    }
                    calculate_hash ();
                }
            }
        }

        public File file { get; private set; }

        public string mime_type { get; set; default = ""; }
        public int year { get; set; default = 0; }
        public int month { get; set; default = 0; }
        public int day { get; set; default = 0; }
        public int hour { get; set; default = 0; }
        public int minute { get; set; default = 0; }
        public int second { get; set; default = 0; }
        public int rotation { get; private set; default = 1; }
        public int width { get; private set; default = 0; }
        public int height { get; private set; default = 0; }
        public string date { get; private set; default = ""; }
        public int iso_speed { get; private set; default = 0; }
        public double fnumber { get; private set; default = 0; }
        public double focal_length { get; private set; default = 0; }
        public int objective_zoom { get; private set; default = 0; }
        public int exposure_time_nom { get; private set; default = 0; }
        public int exposure_time_den { get; private set; default = 0; }

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

        Gdk.Pixbuf ? _original = null;
        public Gdk.Pixbuf ? original {
            get {
                create_original ();
                return _original;
            } private set {
                if (_original != value ) {
                    _original = value;
                }
            }
        }

        public bool is_raw {
            get {
                return Utils.is_raw (mime_type);
            }
        }

        GExiv2.Metadata ? exiv_data = null;
        FileMonitor ? monitor = null;

        bool preview_creating = false;
        bool exiv_excluded = false;
        public bool extern_file { get; set; default = false; }

        construct {
            removed.connect (
                () => {
                    if (album != null) {
                        album.picture_removed (this);
                    }

                    file.trash_async.begin (
                        0,
                        null,
                        (obj, res) => {
                            file.dispose ();
                        });

                    if (preview_path != "") {
                        var f = File.new_for_path (preview_path);
                        f.trash_async.begin (
                            0,
                            null,
                            (obj, res) => {
                                f.dispose ();
                            });
                    }
                });
        }

        public Picture (Album ? album = null, bool extern_file = false) {
            this.album = album;
            this.extern_file = extern_file;
        }

        private void reload () {
            rotation = Utils.Exiv2.convert_rotation_from_exiv (exiv_data.get_orientation ());
            _original.dispose ();
            _original = null;
            create_preview.begin (true);
        }

        public void create_original (bool force = false) {
            if (_original != null && !force) {
                return;
            }
            string p = path;
            File dest_file = null;
            if (source_type == SourceType.MTP || source_type == SourceType.GPHOTO) {
                p = GLib.Path.build_filename (ShowMyPicturesApp.instance.CACHE_FOLDER, "ext_view.png");
                dest_file = File.new_for_path (p);
                try {
                    file.copy (dest_file, FileCopyFlags.OVERWRITE);
                    _path = p;
                } catch (Error err) {
                    warning (err.message);
                    return;
                }
            }

            exclude_exiv ();

            if (is_raw) {
                p = GLib.Path.build_filename (ShowMyPicturesApp.instance.CACHE_FOLDER, "raw_view.tiff");
                LibRaw.Processor processor = new LibRaw.Processor ();
                processor.open_file (path);
                processor.unpack_thumb ();
                processor.thumb_writer (p);
                processor = null;
            }

            try {
                var r = Utils.get_rotation (this);
                if (r != Gdk.PixbufRotation.NONE) {
                    original = new Gdk.Pixbuf.from_file (p).rotate_simple (r);
                } else {
                    original = new Gdk.Pixbuf.from_file (p);
                }
            } catch (Error err) {
                        warning (err.message);
            }

            if (dest_file != null && dest_file.query_exists ()) {
                try {
                    dest_file.delete ();
                } catch (Error err) {
                        warning (err.message);
                }
            }
        }

        private async void create_preview (bool force = false) {
            if (preview_creating || (_preview != null && !force)) {
                return;
            }
            preview_creating = true;

            if (preview != null && !force) {
                preview_creating = false;
                return;
            }

            if (!force) {
                if (GLib.FileUtils.test (preview_path, GLib.FileTest.EXISTS)) {
                    try {
                        preview = new Gdk.Pixbuf.from_file (preview_path);
                    } catch (Error err) {
                        warning (err.message);
                    }
                }
            }
            if ((preview == null || force)) {
                if (is_raw || mime_type == "image/gif") {
                    create_original ();
                    create_preview_from_pixbuf (original, true);
                } else {
                    create_preview_from_path (path);
                }
            }
            preview_creating = false;
        }

        private void create_preview_from_pixbuf (Gdk.Pixbuf pixbuf, bool ignore_rotate = false) {
            exclude_exiv ();
            var r = Utils.get_rotation (this);
            Gdk.Pixbuf ? p = null;
            if (r != Gdk.PixbufRotation.NONE && !ignore_rotate) {
                p = Utils.align_and_scale_pixbuf_for_preview (pixbuf.rotate_simple (r));
            } else {
                p = Utils.align_and_scale_pixbuf_for_preview (pixbuf);
            }

            preview = p;
            p.dispose ();
            p = null;

            if (preview_path != "") {
                new Thread<void*> (
                    "create_preview_from_pixbuf",
                    () => {
                        try {
                            preview.save (preview_path, "png");
                        } catch (Error err) {
                            warning (err.message);
                        }
                        return null;
                    });
            }
        }

        private void create_preview_from_path (string source_path) {
            try {
                create_preview_from_pixbuf (new Gdk.Pixbuf.from_file_at_scale (source_path, -1, 256, true));
            } catch (Error err) {
                warning (err.message);
            }
        }

        public void exclude_exiv () {
            if (exiv_excluded || !open_exiv ()) {
                return;
            }

            int nom = 0;
            int den = 0;
            exiv_data.get_exposure_time (out nom, out den);
            exposure_time_nom = nom;
            exposure_time_den = den;
            rotation = Utils.Exiv2.convert_rotation_from_exiv (exiv_data.get_orientation ());
            width = exiv_data.get_pixel_width ();
            height = exiv_data.get_pixel_height ();
            iso_speed = exiv_data.get_iso_speed ();
            fnumber = exiv_data.get_fnumber ();
            focal_length = exiv_data.get_focal_length ();
            if (mime_type == "") {
                try {
                    var file_info = file.query_info (FileAttribute.STANDARD_CONTENT_TYPE, FileQueryInfoFlags.NONE);
                    mime_type = file_info.get_content_type ();
                    file_info.dispose ();
                } catch (Error err) {
                    warning (err.message);
                }
            }
            date = exiv_data.get_tag_string ("Exif.Photo.DateTimeOriginal");
            if (date != null && date != "") {
                var datetime = Utils.get_datetime_from_string (date);
                if (datetime != null) {
                    year = datetime.get_year ();
                    month = datetime.get_month ();
                    day = datetime.get_day_of_month ();
                    hour = datetime.get_hour ();
                    minute = datetime.get_minute ();
                    second = datetime.get_second ();
                    date = datetime.format ("%e. %b, %Y - %T").strip ();
                }
                datetime = null;
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
                reload ();
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
                reload ();
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

            try {
                if (path.down ().has_suffix ("svg") || path.has_prefix ("mtp:") || path.has_prefix ("gphoto2:") || !exiv_data.open_path (path)) {
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
            FileInfo info = null;
            try {
                info = file.query_info ("time::*", 0);
            } catch (Error err) {
                    warning (err.message);
                return;
            }
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
                    hour = datetime.get_hour ();
                    minute = datetime.get_minute ();
                    second = datetime.get_second ();
                }
                datetime = null;
            }
        }

        private void calculate_hash () {
            if (source_type == SourceType.EXTERNAL) {
                return;
            }
            File ? dest_file = null;
            var tmp_path = path;

            if (!extern_file) {
                Checksum checksum = new Checksum (ChecksumType.MD5);

                checksum.update (path.data, path.length);
                var path_hash = checksum.get_string ();
                tmp_path = Path.build_filename (Environment.get_tmp_dir (), path_hash + "." + Utils.get_file_extention (path));

                dest_file = File.new_for_path (tmp_path);

                try {
                    file.copy (dest_file, FileCopyFlags.OVERWRITE);
                    if (mime_type == "") {
                        FileInfo info = dest_file.query_info ("standard::*", 0);
                        mime_type = info.get_content_type ();
                    }
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
                if (ID != 0) {
                    Services.DataBaseManager.instance.update_picture (this);
                }
            }
            new Thread<void*> (
                "calculate_hash",
                () => {
                    create_preview_from_path (tmp_path);
                    try {
                        if (dest_file != null && dest_file.query_exists ()) {
                            dest_file.delete ();
                        }
                    } catch (Error err) {
                        warning ("%s: %s".printf (err.message, tmp_path));
                    }
                    return null;
                });
        }

        public bool file_exists () {
            bool return_value = true;
            if (!file.query_exists ()) {
                file_not_found ();
                return_value = false;
            }
            return return_value;
        }

        public bool contains_keyword (string keyword) {
            var pic_keywords = keywords.down ();
            return pic_keywords == keyword || pic_keywords.has_prefix (keyword + ",") || pic_keywords.contains ("," + keyword + ",") || pic_keywords.has_suffix ("," + keyword);
        }

        public void start_monitoring () {
            if (monitor == null) {
                try {
                    monitor = file.monitor_file (FileMonitorFlags.NONE);
                } catch (Error err) {
                    warning (err.message);
                }
                if (monitor == null) {
                    return;
                }
                monitor.changed.connect (
                    (file, other_file, event) => {
                        if (event == FileMonitorEvent.CHANGES_DONE_HINT) {
                            calculate_hash ();
                            create_original (true);
                            external_modified ();
                        }
                    });
            }
        }

        public void stop_monitoring () {
            if (monitor != null) {
                monitor.cancel ();
                monitor.dispose ();
                monitor = null;
            }
        }

        public int optimize () {
            if (mime_type.index_of ("jpg") > -1 || mime_type.index_of ("jpeg") > -1) {
                return optimize_jpg ();
            }

            if (mime_type.index_of ("png") > -1) {
                return optimize_png ();
            }

            return 0;
        }

        private int optimize_jpg () {
            var command = "jpegoptim";

            string stdout;
            string stderr;
            int status;

            try {
                Process.spawn_command_line_sync (
                    command + " " + path.replace (" ", "\\ "),
                    out stdout,
                    out stderr,
                    out status
                    );
                return Utils.get_optimized_size_from_jpegoptim (stdout);
            } catch (SpawnError e) {
                stdout.printf ("Error: %s\n", e.message);
            }

            return 0;
        }

        private int optimize_png () {
            var command = "optipng";

            string stdout;
            string stderr;
            int status;

            try {
                Process.spawn_command_line_sync (
                    command + " " + path.replace (" ", "\\ "),
                    out stdout,
                    out stderr,
                    out status
                    );
                return Utils.get_optimized_size_from_optipng (stderr);
            } catch (SpawnError e) {
                stdout.printf ("Error: %s\n", e.message);
            }

            return 0;
        }
    }
}
