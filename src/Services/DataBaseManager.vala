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
    public class DataBaseManager : GLib.Object {
        static DataBaseManager _instance = null;
        public static DataBaseManager instance {
            get {
                if (_instance == null) {
                    _instance = new DataBaseManager ();
                }
                return _instance;
            }
        }

        public signal void added_new_album (Objects.Album album);
        public signal void removed_album (Objects.Album album);
        public signal void keywords_changed ();

        GLib.List<Objects.Album> _albums = null;
        public GLib.List<Objects.Album> albums {
            get {
                if (_albums == null) {
                    _albums = get_album_collection ();
                }
                return _albums;
            }
        }

        Sqlite.Database db;
        string errormsg;

        construct {
            removed_album.connect (
                (album) => {
                _albums.remove (album);
                album.removed ();
            });
        }

        private DataBaseManager () {
            open_database ();
        }

        private void open_database () {
            Sqlite.Database.open (ShowMyPicturesApp.instance.DB_PATH, out db);

            string q;

            q = """CREATE TABLE IF NOT EXISTS albums (
                ID          INTEGER     PRIMARY KEY AUTOINCREMENT,
                title       TEXT        NOT NULL,
                year        INT         NOT NULL,
                month       INT         NOT NULL,
                day         INT         NOT NULL,
                keywords    TEXT        NOT NULL,
                comment     TEXT        NOT NULL,
                CONSTRAINT unique_box UNIQUE (title, year, month)
                );""";
            if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                warning (errormsg);
            }

            q = """CREATE TABLE IF NOT EXISTS pictures (
                ID          INTEGER     PRIMARY KEY AUTOINCREMENT,
                album_id    INT         NOT NULL,
                path        TEXT        NOT NULL,
                mime_type   TEXT        NOT NULL,
                year        INT         NOT NULL,
                month       INT         NOT NULL,
                day         INT         NOT NULL,
                hour        INT         NOT NULL,
                minute      INT         NOT NULL,
                second      INT         NOT NULL,
                keywords    TEXT        NOT NULL,
                hash        TEXT        NOT NULL,
                comment     TEXT        NOT NULL,
                stars       INT         NOT NULL,
                colors      TEXT        NOT NULL,
                CONSTRAINT unique_video UNIQUE (path),
                FOREIGN KEY (album_id) REFERENCES albums (ID)
                    ON DELETE CASCADE
                );""";
            if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                warning (errormsg);
            }

            q = """PRAGMA foreign_keys=ON;""";
            if (db.exec (q, null, out errormsg) != Sqlite.OK) {
                warning (errormsg);
            }
        }

        public void reset_database () {
            File db_path = File.new_for_path (ShowMyPicturesApp.instance.DB_PATH);
            try {
                db_path.delete ();
            } catch (Error err) {
                warning (err.message);
            }
            _albums = new GLib.List<Objects.Album> ();
            open_database ();
        }
// ALBUM REGION
        private GLib.List<Objects.Album> get_album_collection () {
            GLib.List<Objects.Album> return_value = new GLib.List<Objects.Album> ();

            Sqlite.Statement stmt;

            string sql = """
                SELECT id, title, year, month, day, keywords, comment FROM albums ORDER BY year DESC, month DESC, day DESC, title;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);

            while (stmt.step () == Sqlite.ROW) {
                var album = _fill_album (stmt);
                return_value.append (album);
            }
            stmt.reset ();

            return return_value;
        }

        public Objects.Album _fill_album (Sqlite.Statement stmt) {
            Objects.Album return_value = new Objects.Album (stmt.column_text (1));
            return_value.ID = stmt.column_int (0);
            return_value.year = stmt.column_int (2);
            return_value.month = stmt.column_int (3);
            return_value.day = stmt.column_int (4);
            return_value.keywords = stmt.column_text (5);
            return_value.comment = stmt.column_text (6);
            return return_value;
        }

        public void update_album (Objects.Album album) {
            Sqlite.Statement stmt;

            string sql = """
                UPDATE albums SET year=$YEAR, month=$MONTH, day=$DAY, title=$TITLE, keywords=$KEYWORDS, comment=$COMMENT WHERE id=$ID;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$ID", album.ID);
            set_parameter_int (stmt, sql, "$YEAR", album.year);
            set_parameter_int (stmt, sql, "$MONTH", album.month);
            set_parameter_int (stmt, sql, "$DAY", album.day);
            set_parameter_str (stmt, sql, "$TITLE", album.title);
            set_parameter_str (stmt, sql, "$KEYWORDS", album.keywords);
            set_parameter_str (stmt, sql, "$COMMENT", album.comment);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            } else {
                album.updated ();
            }
            stmt.reset ();
        }

        public void insert_album (Objects.Album album) {
            Sqlite.Statement stmt;

            string sql = """
                INSERT INTO albums (year, month, day, title, keywords, comment)
                VALUES ($YEAR, $MONTH, $DAY, $TITLE, $KEYWORDS, $COMMENT);
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$YEAR", album.year);
            set_parameter_int (stmt, sql, "$MONTH", album.month);
            set_parameter_int (stmt, sql, "$DAY", album.day);
            set_parameter_str (stmt, sql, "$TITLE", album.title);
            set_parameter_str (stmt, sql, "$KEYWORDS", album.keywords);
            set_parameter_str (stmt, sql, "$COMMENT", album.comment);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }
            stmt.reset ();

            sql = """
                SELECT id FROM albums WHERE year=$YEAR AND month=$MONTH AND day=$DAY;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$YEAR", album.year);
            set_parameter_int (stmt, sql, "$MONTH", album.month);
            set_parameter_int (stmt, sql, "$DAY", album.day);

            if (stmt.step () == Sqlite.ROW) {
                album.ID = stmt.column_int (0);
                _albums.append (album);
                added_new_album (album);
                stdout.printf ("Album ID: %d - %s\n", album.ID, album.title);
            } else {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }
            stmt.reset ();
        }

        public Objects.Album insert_album_if_not_exists (Objects.Album new_album) {
            Objects.Album? return_value = null;
            lock (_albums) {
                foreach (var album in albums) {
                    if ((album.year == 0 && album.title == new_album.title) || (album.year == new_album.year && album.month == new_album.month && album.day == new_album.day)) {
                        return_value = album;
                        break;
                    }
                }
                if (return_value == null) {
                    insert_album (new_album);
                    return_value = new_album;
                }
            }
            return return_value;
        }

        public void remove_album (Objects.Album album) {
            Sqlite.Statement stmt;

            string sql = """
                DELETE FROM albums WHERE id=$ID;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$ID", album.ID);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            } else {
                stdout.printf ("Album Removed: %d\n", album.ID);
                removed_album (album);
            }
            stmt.reset ();
        }

// PICTURE REGION
        public GLib.List<Objects.Picture> get_picture_collection (Objects.Album album) {
            GLib.List<Objects.Picture> return_value = new GLib.List<Objects.Picture> ();

            Sqlite.Statement stmt;

            string sql = """
                SELECT id, path, year, month, day, mime_type, keywords, hash, comment, stars, colors, hour, minute, second FROM pictures WHERE album_id=$ALBUM_ID ORDER BY year, month, day, hour, minute, second, path;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$ALBUM_ID", album.ID);

            while (stmt.step () == Sqlite.ROW) {
                var picture = _fill_picture (stmt, album);
                return_value.append (picture);
            }
            stmt.reset ();

            return return_value;
        }

        public GLib.List<Objects.Picture> get_picture_collection_by_hash (string hash) {
            GLib.List<Objects.Picture> return_value = new GLib.List<Objects.Picture> ();

            Sqlite.Statement stmt;

            string sql = """
                SELECT id, path, year, month, day, mime_type, keywords, hash, comment, stars, colors, hour, minute, second FROM pictures WHERE hash=$HASH ORDER BY year, month, day, hour, minute, second, path;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_str (stmt, sql, "$HASH", hash);

            while (stmt.step () == Sqlite.ROW) {
                var picture = _fill_picture (stmt, null);
                return_value.append (picture);
            }
            stmt.reset ();

            return return_value;
        }

        public Objects.Picture _fill_picture (Sqlite.Statement stmt, Objects.Album? album) {
            Objects.Picture return_value = new Objects.Picture (album);
            return_value.ID = stmt.column_int (0);
            return_value.path = stmt.column_text (1);
            return_value.year = stmt.column_int (2);
            return_value.month = stmt.column_int (3);
            return_value.day = stmt.column_int (4);
            return_value.mime_type = stmt.column_text (5);
            return_value.keywords = stmt.column_text (6);
            return_value.hash = stmt.column_text (7);
            return_value.comment = stmt.column_text (8);
            return_value.stars = stmt.column_int (9);
            return_value.colors = stmt.column_text (10);
            return_value.hour = stmt.column_int (11);
            return_value.minute = stmt.column_int (12);
            return_value.second = stmt.column_int (13);
            return return_value;
        }

        public void insert_picture (Objects.Picture picture) {
            Sqlite.Statement stmt;

            string sql = """
                INSERT INTO pictures (album_id, path, year, month, day, hour, minute, second, mime_type, keywords, hash, comment, stars, colors)
                VALUES ($ALBUM_ID, $PATH, $YEAR, $MONTH, $DAY, $HOUR, $MINUTE, $SECOND, $MIME_TYPE, $KEYWORDS, $HASH, $COMMENT, $STARS, $COLORS);
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$ALBUM_ID", picture.album.ID);
            set_parameter_str (stmt, sql, "$PATH", picture.path);
            set_parameter_int (stmt, sql, "$YEAR", picture.year);
            set_parameter_int (stmt, sql, "$MONTH", picture.month);
            set_parameter_int (stmt, sql, "$DAY", picture.day);
            set_parameter_int (stmt, sql, "$HOUR", picture.hour);
            set_parameter_int (stmt, sql, "$MINUTE", picture.minute);
            set_parameter_int (stmt, sql, "$SECOND", picture.second);
            set_parameter_str (stmt, sql, "$MIME_TYPE", picture.mime_type);
            set_parameter_str (stmt, sql, "$KEYWORDS", picture.keywords.strip ());
            set_parameter_str (stmt, sql, "$HASH", picture.hash);
            set_parameter_str (stmt, sql, "$COMMENT", picture.comment.strip ());
            set_parameter_int (stmt, sql, "$STARS", picture.stars);
            set_parameter_str (stmt, sql, "$COLORS", picture.colors.strip ());

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }
            stmt.reset ();

            sql = """
                SELECT id FROM pictures WHERE path=$PATH;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_str (stmt, sql, "$PATH", picture.path);

            if (stmt.step () == Sqlite.ROW) {
                picture.ID = stmt.column_int (0);
                stdout.printf ("Picture ID: %d - %s\n", picture.ID, picture.album.title);
            } else {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }
            stmt.reset ();
        }

        public void update_picture (Objects.Picture picture) {
            Sqlite.Statement stmt;

            string sql = """
                UPDATE pictures SET album_id=$ALBUM_ID, keywords=$KEYWORDS, comment=$COMMENT, stars=$STARS, colors=$COLORS, hash=$HASH WHERE id=$ID;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$ID", picture.ID);
            set_parameter_int (stmt, sql, "$ALBUM_ID", picture.album.ID);
            set_parameter_str (stmt, sql, "$KEYWORDS", picture.keywords.strip ());
            set_parameter_str (stmt, sql, "$COMMENT", picture.comment.strip ());
            set_parameter_int (stmt, sql, "$STARS", picture.stars);
            set_parameter_str (stmt, sql, "$COLORS", picture.colors.strip ());
            set_parameter_str (stmt, sql, "$HASH", picture.hash);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            } else {
                picture.updated ();
            }
            stmt.reset ();
        }

        public void remove_picture (Objects.Picture picture) {
            Sqlite.Statement stmt;

            string sql = """
                DELETE FROM pictures WHERE id=$ID;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_int (stmt, sql, "$ID", picture.ID);

            if (stmt.step () != Sqlite.DONE) {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            } else {
                stdout.printf ("Picture Removed: %d\n", picture.ID);
                picture.removed ();
            }
            stmt.reset ();
        }

// KEYWORDS
        public GLib.List<string> get_keyword_collection () {
            GLib.List<string> return_value = new GLib.List<string> ();
            Sqlite.Statement stmt;

            string sql = """
                WITH SPLIT (keyword, str, hascomma) AS (
                    SELECT * FROM (SELECT '', LOWER (keywords), 1 FROM albums WHERE keywords <> ''
                    UNION
                    SELECT '', LOWER (keywords), 1 FROM pictures WHERE keywords <> '')
                    UNION ALL SELECT
                    SUBSTR (str, 0,
                        CASE WHEN INSTR (str, ',')
                        THEN INSTR (str, ',')
                        ELSE LENGTH (str) + 1 END),
                    LTRIM (SUBSTR (str, INSTR (str, ',')), ','),
                    INSTR (str, ',')
                    FROM split
                    WHERE hascomma
                )
                SELECT DISTINCT TRIM (keyword) AS keyword FROM split WHERE keyword != '' ORDER BY TRIM (keyword)
            """;

            db.prepare_v2 (sql, sql.length, out stmt);

            while (stmt.step () == Sqlite.ROW) {
                return_value.append (stmt.column_text (0));
            }
            stmt.reset ();

            return return_value;
        }

// UTILITIES REGION
        public bool picture_file_exists (string path) {
            bool return_value = false;
            Sqlite.Statement stmt;

            string sql = """
                SELECT COUNT (*) FROM pictures WHERE path=$PATH;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_str (stmt, sql, "$PATH", path);

            if (stmt.step () == Sqlite.ROW) {
                return_value = stmt.column_int (0) > 0;
            } else {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }
            stmt.reset ();

            return return_value;
        }

        public bool hash_exists (string hash) {
            bool return_value = false;
            Sqlite.Statement stmt;

            string sql = """
                SELECT COUNT (*) FROM pictures WHERE hash=$HASH;
            """;

            db.prepare_v2 (sql, sql.length, out stmt);
            set_parameter_str (stmt, sql, "$HASH", hash);

            if (stmt.step () == Sqlite.ROW) {
                return_value = stmt.column_int (0) > 0;
            } else {
                warning ("Error: %d: %s", db.errcode (), db.errmsg ());
            }
            stmt.reset ();

            return return_value;
        }

        public GLib.List<string> get_hash_duplicates () {
            GLib.List<string> return_value = new GLib.List<string> ();
            Sqlite.Statement stmt;

            string sql = """
                SELECT hash FROM pictures
                WHERE hash <> ''
                GROUP BY hash HAVING COUNT (hash) > 1
                ORDER BY MIN (path);
            """;

            db.prepare_v2 (sql, sql.length, out stmt);

            while (stmt.step () == Sqlite.ROW) {
                return_value.append (stmt.column_text (0));
            }
            stmt.reset ();

            return return_value;
        }

// PARAMENTER REGION
        private void set_parameter_int (Sqlite.Statement? stmt, string sql, string par, int val) {
            int par_position = stmt.bind_parameter_index (par);
            stmt.bind_int (par_position, val);
        }

        private void set_parameter_str (Sqlite.Statement? stmt, string sql, string par, string val) {
            int par_position = stmt.bind_parameter_index (par);
            stmt.bind_text (par_position, val);
        }
    }
}
