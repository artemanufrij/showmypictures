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

namespace ShowMyPictures.Dialogs {
    public class Preferences : Gtk.Dialog {
        Settings settings;

        construct {
            settings = Settings.get_default ();
        }

        public Preferences (Gtk.Window parent) {
            Object (
                transient_for: parent,
                deletable: false,
                use_header_bar: 1
                );
            build_ui ();
        }

        private void build_ui () {
            this.resizable = false;

            var switcher = new Gtk.StackSwitcher ();
            switcher.margin_top = 12;

            var stack = new Gtk.Stack ();
            switcher.stack = stack;

            var header = this.get_header_bar () as Gtk.HeaderBar;
            header.set_custom_title (switcher);

            var genera_grid = new Gtk.Grid ();
            genera_grid.column_spacing = 12;
            genera_grid.row_spacing = 12;
            genera_grid.margin = 12;

            var use_dark_theme = new Gtk.Switch ();
            use_dark_theme.active = settings.use_dark_theme;
            use_dark_theme.notify["active"].connect (
                () => {
                    settings.use_dark_theme = use_dark_theme.active;
                });

            var sync_files = new Gtk.Switch ();
            sync_files.active = settings.sync_files;
            sync_files.notify["active"].connect (
                () => {
                    settings.sync_files = sync_files.active;
                });

            var check_duplicates = new Gtk.Switch ();
            check_duplicates.active = settings.check_for_duplicates;
            check_duplicates.notify["active"].connect (
                () => {
                    settings.check_for_duplicates = check_duplicates.active;
                });

            var check_missing = new Gtk.Switch ();
            check_missing.active = settings.check_for_missing_files;
            check_missing.notify["active"].connect (
                () => {
                    settings.check_for_missing_files = check_missing.active;
                });

            genera_grid.attach (label_generator (_ ("Use Dark Theme")), 0, 0);
            genera_grid.attach (use_dark_theme, 1, 0);
            genera_grid.attach (new Gtk.Separator (Gtk.Orientation.HORIZONTAL), 0, 1, 2, 1);
            genera_grid.attach (label_generator (_ ("Sync files on start up")), 0, 2);
            genera_grid.attach (sync_files, 1, 2);
            genera_grid.attach (label_generator (_ ("Check for duplicates")), 0, 3);
            genera_grid.attach (check_duplicates, 1, 3);
            genera_grid.attach (label_generator (_ ("Check for missing files")), 0, 4);
            genera_grid.attach (check_missing, 1, 4);

            var fastview_grid = new Gtk.Grid ();
            fastview_grid.column_spacing = 12;
            fastview_grid.row_spacing = 12;
            fastview_grid.margin = 12;

            var use_fastview_multiwindow = new Gtk.Switch ();
            use_fastview_multiwindow.active = settings.use_fastview_multiwindow;
            use_fastview_multiwindow.notify["active"].connect (
                () => {
                    settings.use_fastview_multiwindow = use_fastview_multiwindow.active;
                });

            var use_fastview = new Gtk.Switch ();
            use_fastview.active = settings.use_fastview;
            use_fastview.notify["active"].connect (
                () => {
                    settings.use_fastview = use_fastview.active;
                    use_fastview_multiwindow.sensitive = settings.use_fastview;
                });

            fastview_grid.attach (label_generator (_ ("Use Fast View")), 0, 0);
            fastview_grid.attach (use_fastview, 1, 0);
            fastview_grid.attach (label_generator (_ ("Multiwindow")), 0, 1);
            fastview_grid.attach (use_fastview_multiwindow, 1, 1);

            var import_grid = new Gtk.Grid ();
            import_grid.column_spacing = 12;
            import_grid.row_spacing = 12;
            import_grid.margin = 12;

            var import_location = new Gtk.FileChooserButton (_ ("Import Location"), Gtk.FileChooserAction.SELECT_FOLDER);
            import_location.sensitive = !settings.import_into_default_location;
            if (!settings.import_into_default_location && FileUtils.test (settings.import_location, FileTest.EXISTS)) {
                import_location.set_current_folder (settings.import_location);
            } else {
                import_location.set_current_folder (settings.library_location);
            }
            import_location.file_set.connect (
                () => {
                    settings.import_location = import_location.get_filename ();
                });

            var use_library_for_import = new Gtk.Switch ();
            use_library_for_import.halign = Gtk.Align.END;
            use_library_for_import.active = settings.import_into_default_location;
            use_library_for_import.notify["active"].connect (
                () => {
                    settings.import_into_default_location = use_library_for_import.active;
                    import_location.sensitive = !settings.import_into_default_location;
                });

            import_grid.attach (label_generator (_ ("Import Pictures into Library")), 0, 0);
            import_grid.attach (use_library_for_import, 1, 0);
            import_grid.attach (label_generator (_ ("Location for imported Files")), 0, 1);
            import_grid.attach (import_location, 1, 1);

            stack.add_titled (genera_grid, "general", _ ("General"));
            stack.add_titled (fastview_grid, "fastview", _ ("Fast View"));
            stack.add_titled (import_grid, "import", _ ("Import"));

            var content = this.get_content_area () as Gtk.Box;
            content.pack_start (stack, false, false, 0);

            var close_button = new Gtk.Button.with_label (_ ("Close"));
            close_button.clicked.connect (() => { this.destroy (); });

            Gtk.Box actions = this.get_action_area () as Gtk.Box;
            actions.add (close_button);

            this.show_all ();
        }

        private Gtk.Label ? label_generator (string content) {
            return new Gtk.Label (content) {
                halign = Gtk.Align.START,
                hexpand = true
            };
        }
    }
}
