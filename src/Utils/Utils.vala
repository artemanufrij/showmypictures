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

namespace ShowMyPictures.Utils {
    public static string get_month_name (int month) {
        var date_time = new DateTime.local (1, month, 1, 0, 0, 0);
        return date_time.format ("%B");
    }

    public static string get_file_extention (string path) {
        var split = path.split (".");
        if (split.length > 0) {
            return split [split.length - 1];
        }
        return "";
    }

    public static string format_saved_size (int bytes) {
        if (bytes > 100000000) {
            return _ ("%.0fMB saved").printf ((double)bytes / 1000 / 1000);
        } else if (bytes > 1000000) {
            return _ ("%.1fMB saved").printf ((double)bytes / 1000 / 1000);
        }
        return _ ("%.2fMB saved").printf ((double)bytes / 1000 / 1000);
    }

    public static bool is_valid_mime_type (string mime_type) {
        return mime_type.has_prefix ("image/png")
               || mime_type.has_prefix ("image/jpeg")
               || mime_type == "image/svg+xml"
               || mime_type == "image/x-canon-cr2"
               || mime_type == "image/x-nikon-nef"
               || mime_type == "image/x-sony-arw";
    }

    public static bool is_valid_extention (string extention) {
        return extention.has_suffix ("png")
               || extention.has_suffix ("jpeg")
               || extention.has_suffix ("jpg")
               || extention.has_suffix ("cr2")
               || extention.has_suffix ("nef");
    }

    public static bool is_raw (string mime_type) {
        return mime_type == "image/x-canon-cr2"
               || mime_type == "image/x-nikon-nef"
               || mime_type == "image/x-sony-arw";
    }

    public static DateTime ? get_datetime_from_string (string input) {
        var split = input.split (" ");
        if (split.length == 2) {
            int Y = 0;
            int M = 0;
            int D = 0;
            int h = 0;
            int m = 0;
            int s = 0;

            split [0].scanf ("%d:%d:%d", &Y, &M, &D);
            split [1].scanf ("%d:%d:%d", &h, &m, &s);

            return new DateTime.local (Y, M, D, h, m, s);
        }

        return null;
    }

    public static string format_keywords (string keywords) {
        string return_value = keywords;
        while (return_value.index_of ("  ") >= 0) {
            return_value = return_value.replace ("  ", " ");
        }

        return_value = return_value.replace (" ,", ",");
        return_value = return_value.replace (", ", ",");
        return return_value;
    }

    public int get_optimized_size_from_jpegoptim (string output_line) {
        Regex regex_old;
        Regex regex_new;

        try {
            regex_old = new Regex ("\\d*(?= \\-\\->)");
            regex_new = new Regex ("(?<=\\-\\-\\> )\\d*");
        } catch (Error err) {
            warning (err.message);
            return 0;
        }

        int old_value = 0;
        MatchInfo match_info;
        if (regex_old.match (output_line, 0, out match_info)) {
            old_value = int.parse (match_info.fetch (0));
        }

        int new_value = 0;
        if (regex_new.match (output_line, 0, out match_info)) {
            new_value = int.parse (match_info.fetch (0));
        }

        return old_value - new_value;
    }

    public int get_optimized_size_from_optipng (string output_line) {
        Regex regex_old;
        Regex regex_new;

        try {
            regex_old = new Regex ("(?<=Input file size = )\\d*");
            regex_new = new Regex ("(?<=Output file size = )\\d*");
        } catch (Error err) {
            warning (err.message);
            return 0;
        }

        int old_value = 0;
        MatchInfo match_info;
        if (regex_old.match (output_line, 0, out match_info)) {
            old_value = int.parse (match_info.fetch (0));
        }

        int new_value = 0;
        if (regex_new.match (output_line, 0, out match_info)) {
            new_value = int.parse (match_info.fetch (0));
        }

        if (new_value == 0 || old_value == 0) {
            return 0;
        }

        return old_value - new_value;
    }
}
