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

    public static bool is_valid_mime_type (string mime_type) {
        return mime_type.has_prefix ("image/png") || mime_type.has_prefix ("image/jpeg");
    }

    public static DateTime? get_datetime_from_string (string input) {
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
}
