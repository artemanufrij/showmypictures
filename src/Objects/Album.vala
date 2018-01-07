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

        public signal void picture_added (Picture picture);
        public signal void picture_removed (Picture picture);
        public signal void cover_created ();
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
        public string title { get; set; default="";}
        public int year { get; set; default = 0; }
        public int month { get; set; default = 0; }
        public int day { get; set; default = 0; }

        GLib.List<Picture> _pictures = null;
        public GLib.List<Picture> pictures {
            get {
                if (_pictures == null) {
                    _pictures = db_manager.get_picture_collection (this);
                }
                return _pictures;
            }
        }

        Gdk.Pixbuf? _cover = null;
        public Gdk.Pixbuf? cover {
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
            picture_removed.connect ((track) => {
                this._pictures.remove (track);
                if (this.pictures.length () == 0) {
                    db_manager.remove_album (this);
                }
            });
        }

        public Album (string title) {
            this.title = title;
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
                this._pictures.insert_sorted_with_data (new_picture, (a, b) => {
                    return a.path.collate (b.path);
                });
                picture_added (new_picture);
                create_cover.begin ();
            }
        }

        public Picture? get_next_picture (Picture current) {
            int i = _pictures.index (current) + 1;
            if (i < _pictures.length ()) {
                return _pictures.nth_data (i);
            }
            return null;
        }

        public Picture? get_prev_picture (Picture current) {
            int i = _pictures.index (current) - 1;
            if (i > - 1) {
                return _pictures.nth_data (i);
            }
            return null;
        }

        public async void create_cover () {
            if (cover_creating || _cover != null) {
                return;
            }

            new Thread<void*> (null, () => {
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
                try {
                    set_new_cover_from_picture (picture);
                } catch (Error err) {
                    warning (err.message);
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
                picture.exclude_exif ();
                var r = Utils.get_rotation (picture);
                if (r != Gdk.PixbufRotation.NONE) {
                    pixbuf = pixbuf.rotate_simple (r);
                }
                set_new_cover (pixbuf);
            } catch (Error err) {
                warning (err.message);
            }
        }

        public void create_pictures_preview () {
            pictures_preview_creating = true;
            new Thread<void*> (null, () => {
                foreach (var picture in pictures) {
                    picture.create_preview ();
                }
                pictures_preview_creating = false;
                return null;
            });
        }
    }
}
