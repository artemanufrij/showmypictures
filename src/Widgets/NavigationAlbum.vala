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

namespace ShowMyPictures.Widgets {
    public class NavigationAlbum : Granite.Widgets.SourceList.ExpandableItem, Granite.Widgets.SourceListSortable {
        public Objects.Album album { get; private set; }

        public NavigationAlbum (Objects.Album album) {
            this.album = album;
            this.name = this.album.title;
            this.album.removed.connect (
                () => {
                    this.parent.remove (this);
                });
            this.album.updated.connect (
                () => {
                    this.name = this.album.title;
                });
        }

        public int compare (Granite.Widgets.SourceList.Item a, Granite.Widgets.SourceList.Item b) {
            if (a is NavigationAlbum && b is NavigationAlbum) {
                return (b as NavigationAlbum).album.day - ((a as NavigationAlbum).album.day);
            }
            if (a is NavigationAlbum && !(b is NavigationAlbum)) {
                return 1;
            }
            return 0;
        }

        public bool allow_dnd_sorting () {
            return false;
        }
    }
}
