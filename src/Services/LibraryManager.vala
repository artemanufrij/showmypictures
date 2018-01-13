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

        public signal void sync_started ();
        public signal void sync_finished ();
        public signal void non_exists_pictures_found ();
        public signal void duplicates_found (GLib.List<string> hash_list);
        public signal void added_new_album (Objects.Album album);
        public signal void removed_album (Objects.Album album);

        public Services.DataBaseManager db_manager { get; construct set; }
        public Services.LocalFilesManager lf_manager { get; construct set; }

        public GLib.List<Objects.Album> albums {
            get {
                return db_manager.albums;
            }
        }

        int insert_queue = 0;

        uint duplicates_timer = 0;
        GLib.List<string> hash_list = null;
        GLib.List<string> duplicates = null;

        construct {
            settings = ShowMyPictures.Settings.get_default ();

            lf_manager = Services.LocalFilesManager.instance;
            lf_manager.found_image_file.connect (found_local_image_file);
            lf_manager.scan_started.connect (() => { sync_started (); });

            db_manager = Services.DataBaseManager.instance;
            db_manager.added_new_album.connect ((album) => { added_new_album (album); });
            db_manager.removed_album.connect ((album) => { removed_album (album); });
        }

        private LibraryManager () {
            sync_started.connect (
                () => {
                    reset_duplicate_timer ();
                });
        }

        public async void sync_library_content_async (bool force = false) {
            new Thread <void*> (
                "sync_library_content",
                () => {
                    find_non_existent_items ();
                    scan_local_library_for_new_files (settings.library_location);
                    scan_for_duplicates_async.begin ();
                    return null;
                });
        }

        public void found_local_image_file (string path, string mime_type) {
            if (!db_manager.picture_file_exists (path)) {
                insert_queue++;
                insert_picture_file (path, mime_type);
                insert_queue--;
                if (insert_queue == 0) {
                    scan_for_duplicates_async.begin ();
                }
            }
        }

        public void scan_local_library_for_new_files (string path) {
            lf_manager.scan (path);
        }

        private void insert_picture_file (string path, string mime_type) {
            var picture = new Objects.Picture ();
            picture.mime_type = mime_type;
            picture.path = path;

            var album = new Objects.Album ("");
            album.year = picture.year;
            album.month = picture.month;
            album.day = picture.day;
            album.create_default_title ();

            album = db_manager.insert_album_if_not_exists (album);

            if (album.ID > 0) {
                album.add_picture_if_not_exists (picture);
            }
        }

        public async void find_non_existent_items_async () {
            find_non_existent_items ();
        }

        private void find_non_existent_items () {
            sync_started ();
            foreach (var album in albums) {
                foreach (var picture in album.pictures) {
                    if (!picture.file_exists ()) {
                        non_exists_pictures_found ();
                    }
                }
            }
        }

        public async void scan_for_duplicates_async () {
            lock (duplicates_timer) {
                reset_duplicate_timer ();

                if (hash_list != null) {
                    return;
                }

                duplicates_timer = Timeout.add (
                    5000,
                    () => {
                        hash_list = new GLib.List<string>();
                        duplicates = new GLib.List<string> ();
                        foreach (var album in albums) {
                            foreach (var picture in album.pictures) {
                                string hash = picture.hash;
                                if (check_hash (hash)) {
                                    duplicates.append (hash);
                                }
                            }
                        }
                        if (duplicates.length () > 0) {
                            duplicates_found (duplicates);
                        }
                        reset_duplicate_timer ();
                        hash_list = null;
                        sync_finished ();
                        return false;
                    });
            }
        }

        private void reset_duplicate_timer () {
            lock (duplicates_timer) {
                if (duplicates_timer != 0) {
                    Source.remove (duplicates_timer);
                    duplicates_timer = 0;
                }
            }
        }

        private bool check_hash (string hash) {
            bool return_value = false;
            lock (hash_list) {
                hash_list.foreach (
                    (item) => {
                        if (item == hash) {
                            return_value = true;
                            return;
                        }
                    }) ;
                if (!return_value) {
                    hash_list.append (hash);
                }
            }
            return return_value;
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

        public string ? choose_folder () {
            string ? return_value = null;
            Gtk.FileChooserDialog chooser = new Gtk.FileChooserDialog (
                _ ("Select a folder."), ShowMyPicturesApp.instance.mainwindow, Gtk.FileChooserAction.SELECT_FOLDER,
                _ ("_Cancel"), Gtk.ResponseType.CANCEL,
                _ ("_Open"), Gtk.ResponseType.ACCEPT);

            var filter = new Gtk.FileFilter ();
            filter.set_filter_name (_ ("Folder"));
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
