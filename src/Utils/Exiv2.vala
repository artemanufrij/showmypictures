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

namespace ShowMyPictures.Utils.Exiv2 {
    public static int convert_rotation_from_exiv (GExiv2.Orientation orientation) {
        switch (orientation) {
        case GExiv2.Orientation.ROT_90 :
            return 6;
        case GExiv2.Orientation.ROT_180 :
            return 3;
        case GExiv2.Orientation.ROT_270 :
            return 8;
        }
        return 1;
    }

    public static GExiv2.Orientation convert_rotation_to_exiv (int rotation) {
        switch (rotation) {
        case 6 :
            return GExiv2.Orientation.ROT_90;
        case 3 :
            return GExiv2.Orientation.ROT_180;
        case 8 :
            return GExiv2.Orientation.ROT_270;
        }
        return GExiv2.Orientation.NORMAL;
    }

    public static GExiv2.Orientation rotate_left (GExiv2.Orientation orientation) {
        switch (orientation) {
            case GExiv2.Orientation.NORMAL :
                return  GExiv2.Orientation.ROT_270;
            case GExiv2.Orientation.ROT_270 :
                return GExiv2.Orientation.ROT_180;
            case GExiv2.Orientation.ROT_180 :
                return GExiv2.Orientation.ROT_90;
            }
            return GExiv2.Orientation.NORMAL;
    }

    public static GExiv2.Orientation rotate_right (GExiv2.Orientation orientation) {
        switch (orientation) {
            case GExiv2.Orientation.NORMAL :
                return  GExiv2.Orientation.ROT_90;
            case GExiv2.Orientation.ROT_90 :
                return GExiv2.Orientation.ROT_180;
            case GExiv2.Orientation.ROT_180 :
                return GExiv2.Orientation.ROT_270;
            }
            return GExiv2.Orientation.NORMAL;
    }
}