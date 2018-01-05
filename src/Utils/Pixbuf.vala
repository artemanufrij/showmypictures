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
    public static Gdk.Pixbuf? align_and_scale_pixbuf_for_preview (Gdk.Pixbuf p) {
        Gdk.Pixbuf? pixbuf = p;

        int dest_height = 256;
        int dest_width = 0;

        int height = pixbuf.height;
        int width = pixbuf.width;

        dest_width = (int)(width * ((double)dest_height / height));
        pixbuf = pixbuf.scale_simple (dest_width, dest_height, Gdk.InterpType.BILINEAR);
        return pixbuf;
    }

    public Gdk.Pixbuf? align_and_scale_pixbuf_for_cover (Gdk.Pixbuf p) {
        Gdk.Pixbuf? pixbuf = p;
        if (pixbuf.width != pixbuf.height) {
            if (pixbuf.width > pixbuf.height) {
                int dif = (pixbuf.width - pixbuf.height) / 2;
                pixbuf = new Gdk.Pixbuf.subpixbuf (pixbuf, dif, 0, pixbuf.height, pixbuf.height);
            } else {
                int dif = (pixbuf.height - pixbuf.width) / 2;
                pixbuf = new Gdk.Pixbuf.subpixbuf (pixbuf, 0, dif, pixbuf.width, pixbuf.width);
            }
        }
        pixbuf = pixbuf.scale_simple (192, 192, Gdk.InterpType.BILINEAR);
        return pixbuf;
    }

    public static Gdk.PixbufRotation get_rotation (Objects.Picture picture) {
        switch (picture.rotation) {
            case 3:
                return Gdk.PixbufRotation.UPSIDEDOWN;
            case 6:
                return Gdk.PixbufRotation.CLOCKWISE;
            case 8:
                return Gdk.PixbufRotation.COUNTERCLOCKWISE;
            default:
                return Gdk.PixbufRotation.NONE;
        }
    }
}
