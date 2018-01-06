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

namespace ShowMyPictures {
    public class ShowMyPicturesApp : Gtk.Application {
        public string DB_PATH { get; private set; }
        public string CACHE_FOLDER { get; private set; }
        public string PREVIEW_FOLDER { get; private set; }

        ShowMyPictures.Settings settings;

        static ShowMyPicturesApp _instance = null;
        public static ShowMyPicturesApp instance {
            get {
                if (_instance == null) {
                    _instance = new ShowMyPicturesApp ();
                }
                return _instance;
            }
        }

        construct {
            this.flags |= GLib.ApplicationFlags.HANDLES_OPEN;
            this.application_id = "com.github.artemanufrij.showmypictures";
            settings = ShowMyPictures.Settings.get_default ();

            var action_back = new SimpleAction ("back-action", null);
            add_action (action_back);
            add_accelerator ("<Alt>Left", "app.back-action", null);
            action_back.activate.connect (() => {
                if (mainwindow != null) {
                    mainwindow.back_action ();
                }
            });

            var action_forward = new SimpleAction ("forward-action", null);
            add_action (action_forward);
            add_accelerator ("<Alt>Right", "app.forward-action", null);
            action_forward.activate.connect (() => {
                if (mainwindow != null) {
                    mainwindow.forward_action ();
                }
            });

            create_cache_folders ();
        }

        public void create_cache_folders () {
            var library_path = File.new_for_path (settings.library_location);
            if (settings.library_location == "" || !library_path.query_exists ()) {
                settings.library_location = GLib.Environment.get_user_special_dir (GLib.UserDirectory.PICTURES);
            }
            CACHE_FOLDER = GLib.Path.build_filename (GLib.Environment.get_user_cache_dir (), application_id);
            try {
                File file = File.new_for_path (CACHE_FOLDER);
                if (!file.query_exists ()) {
                    file.make_directory ();
                }
            } catch (Error e) {
                warning (e.message);
            }
            DB_PATH = GLib.Path.build_filename (CACHE_FOLDER, "database.db");

            PREVIEW_FOLDER = GLib.Path.build_filename (CACHE_FOLDER, "preview");
            try {
                File file = File.new_for_path (PREVIEW_FOLDER);
                if (!file.query_exists ()) {
                    file.make_directory ();
                }
            } catch (Error e) {
                warning (e.message);
            }
        }

        private ShowMyPicturesApp () { }

        public MainWindow mainwindow { get; private set; default = null; }

        protected override void activate () {
            if (mainwindow == null) {
                mainwindow = new MainWindow ();
                mainwindow.application = this;
            }
            mainwindow.present ();
        }

        public override void open (File[] files, string hint) {
            activate ();
        }
    }
}

public static int main (string [] args) {
    var app = ShowMyPictures.ShowMyPicturesApp.instance;
    return app.run (args);
}
