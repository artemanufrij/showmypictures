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
        public signal void pictures_not_found (GLib.List<Objects.Picture> pictures);
        public signal void duplicates_found (GLib.List<string> hash_list);
        public signal void added_new_album (Objects.Album album);
        public signal void removed_album (Objects.Album album);
        public signal void external_device_added (Volume volume, DeviceType device_type);
        public signal void external_device_removed (Volume volume);

        public Services.DataBaseManager db_manager { get; construct set; }
        public Services.LocalFilesManager lf_manager { get; construct set; }
        public Services.DeviceManager device_manager { get; construct set; }

        public GLib.List<Objects.Album> albums {
            get {
                return db_manager.albums;
            }
        }

        int insert_queue = 0;

        uint duplicates_timer = 0;
        GLib.List<string> duplicates = null;
        GLib.List<Objects.Picture> not_found = null;

        construct {
            settings = ShowMyPictures.Settings.get_default ();

            lf_manager = Services.LocalFilesManager.instance;
            lf_manager.found_image_file.connect (found_local_image_file);
            lf_manager.scan_started.connect (() => { sync_started (); });

            db_manager = Services.DataBaseManager.instance;
            db_manager.added_new_album.connect ((album) => { added_new_album (album); });
            db_manager.removed_album.connect ((album) => { removed_album (album); });

            device_manager = Services.DeviceManager.instance;
            device_manager.external_device_added.connect (
                (volume, device_type) => {
                    external_device_added (volume, device_type);
                });
            device_manager.external_device_removed.connect (
                (volume) => {
                    external_device_removed (volume);
                });
        }

        private LibraryManager () {
        }

        public async void sync_library_content_async (bool force = false) {
            sync_started ();
            new Thread <void*> (
                "sync_library_content",
                () => {
                    if (settings.check_for_missing_files || force) {
                        find_non_existent_items ();
                    }
                    if (settings.sync_files || force) {
                        scan_local_library_for_new_files (settings.library_location);
                    } else if (settings.check_for_duplicates) {
                        scan_for_duplicates_async.begin ();
                    } else {
                        sync_finished ();
                    }
                    return null;
                });
        }

        public void found_local_image_file (string path, string mime_type) {
            if (!db_manager.picture_file_exists (path)) {
                if (duplicates_timer == 0) {
                    sync_started ();
                } else {
                    reset_duplicate_timer ();
                }
                insert_queue++;
                insert_picture_file (path, mime_type);
                insert_queue--;
                if (insert_queue == 0 && settings.check_for_duplicates) {
                    scan_for_duplicates_async.begin ();
                }
            }
        }

        public void scan_local_library_for_new_files (string path) {
            lf_manager.scan (path);
            if (settings.check_for_duplicates) {
                scan_for_duplicates_async.begin ();
            }
        }

        private void insert_picture_file (string path, string mime_type) {
            var picture = new Objects.Picture ();
            picture.mime_type = mime_type;
            picture.path = path;

            var album = new Objects.Album.based_on_picture (picture);
            album = db_manager.insert_album_if_not_exists (album);

            if (album.ID > 0) {
                album.add_picture_if_not_exists (picture);
            }
        }

        private void find_non_existent_items () {
            not_found = new GLib.List<Objects.Picture> ();
            foreach (var album in albums) {
                foreach (var picture in album.pictures) {
                    if (!picture.file_exists ()) {
                        not_found.append (picture);
                    }
                }
            }
            if (not_found.length () > 0) {
                pictures_not_found (not_found);
            }
        }

        public async void scan_for_duplicates_async () {
            lock (duplicates_timer) {
                reset_duplicate_timer ();

                duplicates_timer = Timeout.add (
                    3000,
                    () => {
                        duplicates = db_manager.get_hash_duplicates ();
                        if (duplicates.length () > 0) {
                            duplicates_found (duplicates);
                        }
                        reset_duplicate_timer ();
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
