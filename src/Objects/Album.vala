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

namespace ShowMyPictures.Objects {
    public class Album : GLib.Object {
        ShowMyPictures.Services.DataBaseManager db_manager;

        public signal void picture_added (Picture picture);

        public int ID { get; set; }
        public string title { get; set; }
        public int year { get; set; }
        public int month { get; set; }
        public int day { get; set; }

        public int title_id { get; set; default = 0; }

        GLib.List<Picture> _pictures = null;
        public GLib.List<Picture> pictures {
            get {
                if (_pictures == null) {
                    _pictures = db_manager.get_picture_collection (this);
                }
                return _pictures;
            }
        }

        construct {
            db_manager = ShowMyPictures.Services.DataBaseManager.instance;
        }

        public Album (string title) {
            this.title = title;
        }

        public void add_picture_if_not_exists (Picture new_picture) {
            lock (_pictures) {
                foreach (var picture in pictures) {
                    if (picture.path == new_picture.path) {
                       return;
                    }
                }
                new_picture.album = this;
                db_manager.insert_picture (new_picture);
                this._pictures.append (new_picture);
                picture_added (new_picture);
            }
        }
    }
}
