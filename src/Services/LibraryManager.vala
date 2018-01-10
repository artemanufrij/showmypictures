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

namespace ShowMyPictures.Services {
    public class LibraryManager : GLib.Object {
        Settings settings;

        static LibraryManager _instance = null;
        public static LibraryManager instance {
            get {
                if (_instance == null) {
                    _instance = new LibraryManager ();
                }
                return _instance;
            }
        }
        public signal void duplicates_found (string hash);
        public signal void added_new_album (Objects.Album album);
        public signal void removed_album (Objects.Album album);

        public Services.DataBaseManager db_manager { get; construct set; }
        public Services.LocalFilesManager lf_manager { get; construct set; }

        public GLib.List<Objects.Album> albums {
            get {
                return db_manager.albums;
            }
        }

        uint duplicates_timer = 0;
        GLib.List<string> hash_list = null;

        construct {
            hash_list = new GLib.List<string>();

            settings = ShowMyPictures.Settings.get_default ();

            lf_manager = Services.LocalFilesManager.instance;
            lf_manager.found_image_file.connect (found_local_image_file);

            db_manager = Services.DataBaseManager.instance;
            db_manager.added_new_album.connect ((album) => { added_new_album (album); });
            db_manager.removed_album.connect ((album) => { removed_album (album); });
            db_manager.added_new_picture.connect ((picture) => {
                scan_for_duplicates.begin ();
            });

            duplicates_found.connect ((hash) => {stdout.printf ("%s\n", hash);});
        }

        private LibraryManager () { }

        public async void sync_library_content (bool force = false) {
            new Thread <void*> (null, () => {
                //find_non_existent_items ();
                scan_local_library_for_new_files (settings.library_location);
                scan_for_duplicates.begin ();
                return null;
            });
        }

        public void found_local_image_file (string path, string mime_type) {
            if (!db_manager.picture_file_exists (path)) {
                insert_picture_file (path, mime_type);
            }
        }

        public void scan_local_library_for_new_files (string path) {
            lf_manager.scan (path);
        }

        private void insert_picture_file (string path, string mime_type) {
            var picture = new Objects.Picture ();
            picture.path = path;
            picture.mime_type = mime_type;

            var album = new Objects.Album ("");
            album.year = picture.year;
            album.month = picture.month;
            album.day = picture.day;
            album.title = Utils.get_default_album_title (album.year, album.month, album.day);

            album = db_manager.insert_album_if_not_exists (album);

            if (album.ID > 0) {
                album.add_picture_if_not_exists (picture);
            }
        }

        private void find_non_existent_items () {
            foreach (var album in albums) {
                foreach (var picture in album.pictures) {
                    if (!picture.file_exists ()) {
                        // TODO:
                    }
                }
            }
        }

        public async void scan_for_duplicates () {
            if (duplicates_timer != 0) {
                Source.remove (duplicates_timer);
                duplicates_timer = 0;
            }

            duplicates_timer = Timeout.add (5000, () => {
                foreach (var album in albums) {
                    if (duplicates_timer == 0) {
                        break;
                    }
                    foreach (var picture in album.pictures) {
                        if (duplicates_timer == 0) {
                            break;
                        }
                        check_hash (picture.hash);
                    }
                }
                if (duplicates_timer != 0) {
                    Source.remove (duplicates_timer);
                    duplicates_timer = 0;
                }
                return false;
            });
        }

        private void check_hash (string hash) {
            hash_list.foreach ((item) => {
                if (item == hash) {
                    duplicates_found (hash);
                }
                return;
            });
            hash_list.append (hash);
        }

        public void reset_library () {
            db_manager.reset_database ();
            File directory = File.new_for_path (ShowMyPicturesApp.instance.PREVIEW_FOLDER);
            try {
                var children = directory.enumerate_children ("", 0);
                FileInfo file_info;
                while ((file_info = children.next_file ()) != null) {
                     var file = File.new_for_path (GLib.Path.build_filename (ShowMyPicturesApp.instance.PREVIEW_FOLDER, file_info.get_name ()));
                     file.delete ();
                }
                children.close ();
                children.dispose ();
            } catch (Error err) {
                warning (err.message);
            }
            directory.dispose ();
        }

        public string? choose_folder () {
            string? return_value = null;
            Gtk.FileChooserDialog chooser = new Gtk.FileChooserDialog (
                _("Select a folder."), ShowMyPicturesApp.instance.mainwindow, Gtk.FileChooserAction.SELECT_FOLDER,
                _("_Cancel"), Gtk.ResponseType.CANCEL,
                _("_Open"), Gtk.ResponseType.ACCEPT);

            var filter = new Gtk.FileFilter ();
            filter.set_filter_name (_("Folder"));
            filter.add_mime_type ("inode/directory");

            chooser.add_filter (filter);

            if (chooser.run () == Gtk.ResponseType.ACCEPT) {
                return_value = chooser.get_file ().get_path ();
            }

            chooser.destroy ();
            return return_value;
        }
    }
}
