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
    public class Album : GLib.Object {
        ShowMyPictures.Services.DataBaseManager db_manager;

        public signal void picture_added (Picture picture, uint new_count);
        public signal void picture_removed (Picture picture);
        public signal void cover_created ();
        public signal void updated ();
        public signal void removed ();

        int _ID = 0;
        public int ID {
            get {
                return _ID;
            } set {
                _ID = value;
                if (value > 0) {
                    cover_path = GLib.Path.build_filename (ShowMyPicturesApp.instance.PREVIEW_FOLDER, ("album_%d.jpg").printf (this.ID));
                }
            }
        }

        public string cover_path { get; private set; }
        public string title { get; set; default=""; }
        public int year { get; set; default = 0; }
        public int month { get; set; default = 0; }
        public int day { get; set; default = 0; }

        public string keywords { get; set; default = ""; }
        public string comment { get; set; default = ""; }

        GLib.List<Picture> _pictures = null;
        public GLib.List<Picture> pictures {
            get {
                if (_pictures == null) {
                    _pictures = db_manager.get_picture_collection (this);
                }
                return _pictures;
            }
        }

        Gdk.Pixbuf ? _cover = null;
        public Gdk.Pixbuf ? cover {
            get {
                if (_cover == null) {
                    create_cover.begin ();
                }
                return _cover;
            } private set {
                if (_cover != value) {
                    _cover = value;
                    cover_created ();
                }
            }
        }

        bool cover_creating = false;
        public bool pictures_preview_creating { get; private set; default = false; }

        construct {
            db_manager = ShowMyPictures.Services.DataBaseManager.instance;
            picture_removed.connect (
                (track) => {
                    this._pictures.remove (track);
                    if (this.pictures.length () == 0) {
                        db_manager.remove_album (this);
                    }
                });
            removed.connect (
                () => {
                    var f = File.new_for_path (cover_path);
                    f.trash_async.begin (
                        0,
                        null,
                        (obj, res) => {
                            f.dispose ();
                        });
                });
        }

        public Album (string title) {
            this.title = title;
        }

        public Album.based_on_picture (Picture picture) {
            year = picture.year;
            month = picture.month;
            day = picture.day;
            create_default_title ();
        }

        public void add_picture (Picture picture) {
            lock (_pictures) {
                _pictures.insert_sorted_with_data (
                    picture,
                    (a, b) => {

                        if (a.year != b.year) {
                            return a.year - b.year;
                        }
                        if (a.month != b.month) {
                            return a.month - b.month;
                        }
                        if (a.day != b.day) {
                            return a.day - b.day;
                        }
                        if (a.hour != b.hour) {
                            return a.hour - b.hour;
                        }
                        if (a.minute != b.minute) {
                            return a.minute - b.minute;
                        }
                        if (a.second != b.second) {
                            return a.second - b.second;
                        }

                        return a.path.collate (b.path);
                    });
                picture_added (picture, _pictures.length ());
            }
        }

        public void add_picture_if_not_exists (Picture new_picture) {
            lock (_pictures) {
                foreach (var picture in pictures) {
                    if (picture.path == new_picture.path) {
                        return;
                    }
                }
                new_picture.album = this;
                db_manager.insert_picture (new_picture);
                add_picture (new_picture);
            }
            create_cover.begin ();
        }

        public Picture ? get_first_picture () {
            return this.pictures.first ().data;
        }

        public Picture ? get_next_picture (Picture current) {
            int i = _pictures.index (current) + 1;
            if (i < _pictures.length ()) {
                var next = _pictures.nth_data (i);
                if (next.file_exists ()) {
                    return next;
                }
                return get_next_picture (next);
            }
            return null;
        }

        public Picture ? get_prev_picture (Picture current) {
            int i = _pictures.index (current) - 1;
            if (i > -1) {
                var prev = _pictures.nth_data (i);
                if (prev.file_exists ()) {
                    return prev;
                }
                return get_prev_picture (prev);
            }
            return null;
        }

        public Picture ? get_picture_by_path (string path) {
            foreach (var picture in pictures) {
                if (picture.path == path) {
                    return picture;
                }
            }
            return null;
        }

        public void merge (GLib.List<Objects.Album> albums) {
            foreach (var album in albums) {
                if (album.ID == ID) {
                    continue;
                }
                foreach (var picture in album.pictures) {
                    picture.album = this;
                    add_picture (picture);
                    db_manager.update_picture (picture);
                }
                db_manager.remove_album (album);
            }
        }

        public bool contains_keyword (string keyword, bool check_pictures = true) {
            bool return_value = false;
            if (check_pictures) {
                lock (_pictures) {
                    foreach (var picture in pictures) {
                        if (picture.contains_keyword (keyword)) {
                            return_value = true;
                            break;
                        }
                    }
                }
            }

            if (!return_value) {
                var keywords_album = keywords.down ();
                return_value = keywords_album == keyword || keywords_album.has_prefix (keyword + ",") || keywords_album.contains ("," + keyword + ",") || keywords_album.has_suffix ("," + keyword);
            }
            return return_value;
        }

        public async void create_cover () {
            if (cover_creating || _cover != null) {
                return;
            }

            new Thread<void*> (
                "create_cover",
                () => {
                    cover_creating = true;
                    if (GLib.FileUtils.test (cover_path, GLib.FileTest.EXISTS)) {
                        try {
                            cover = new Gdk.Pixbuf.from_file (cover_path);
                        } catch (Error err) {
                            warning (err.message);
                        }
                    }
                    if (cover != null) {
                        cover_creating = false;
                        return null;
                    }
                    if (pictures.length () == 0) {
                        cover_creating = false;
                        return null;
                    }
                    var picture = pictures.first ().data;
                    if (picture != null) {
                        set_new_cover_from_picture (picture);
                    }
                    cover_creating = false;
                    return null;
                });
        }

        public void set_new_cover (Gdk.Pixbuf pixbuf) {
            cover = Utils.align_and_scale_pixbuf_for_cover (pixbuf);
            try {
                cover.save (cover_path, "jpeg", "quality", "100");
            } catch (Error err) {
                warning (err.message);
            }
            pixbuf.dispose ();
        }

        public void set_new_cover_from_picture (Picture picture) {
            try {
                var pixbuf = new Gdk.Pixbuf.from_file (picture.path);
                picture.exclude_exiv ();
                var r = Utils.get_rotation (picture);
                if (r != Gdk.PixbufRotation.NONE) {
                    pixbuf = pixbuf.rotate_simple (r);
                }
                set_new_cover (pixbuf);
            } catch (Error err) {
                warning (err.message);
            }
        }

        public void create_default_title () {
            if (year > 0 && month > 0 && day > 0) {
                var date_time = new DateTime.local (year, month, day, 0, 0, 0);
                title = date_time.format ("%e. %b, %Y");
            } else {
                title = _ ("No Date");
            }
        }
    }
}
