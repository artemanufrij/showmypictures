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
    public enum DeviceType { DEFAULT, MTP, GPHOTO }

    public class DeviceManager : GLib.Object {
        static DeviceManager _instance = null;

        public static DeviceManager instance {
            get {
                if (_instance == null)
                    _instance = new DeviceManager ();
                return _instance;
            }
        }

        private DeviceManager () {
        }

        public signal void external_device_added (Volume volume, DeviceType device_type);
        public signal void external_device_removed (Volume volume);

        private GLib.VolumeMonitor monitor;

        construct {
            monitor = GLib.VolumeMonitor.get ();

            monitor.volume_added.connect (
                (volume) => {
                    signal_check_add (volume);
                });

            monitor.volume_removed.connect (
                (volume) => {
                    signal_check_remove (volume);
                });
        }

        public void init () {
            var volumes = monitor.get_volumes ();
            foreach (var volume in volumes) {
                signal_check_add (volume);
            }
        }

        private void signal_check_add (Volume volume) {
            if (check_for_mtp_volume (volume)) {
                external_device_added (volume, DeviceType.MTP);
            } else if (check_for_gphoto_volume (volume)) {
                external_device_added (volume, DeviceType.GPHOTO);
            } else {
                var drive = volume.get_drive ();
                if (drive != null) {
                    if (check_for_external_device (drive)) {
                        external_device_added (volume, DeviceType.DEFAULT);
                    }
                    drive.unref ();
                }
            }
        }

        private void signal_check_remove (Volume volume) {
            if (check_for_mtp_volume (volume) || check_for_gphoto_volume (volume)) {
                        external_device_removed (volume);
            } else {
                var drive = volume.get_drive ();
                if (drive != null) {
                    if (check_for_external_device (drive)) {
                        external_device_removed (volume);
                    }
                    drive.unref ();
                }
            }
        }
    }

    private bool check_for_mtp_volume (Volume volume) {
        File file = volume.get_activation_root ();
        return (file != null && file.get_uri ().has_prefix ("mtp://"));
    }

    private bool check_for_gphoto_volume (Volume volume) {
        File file = volume.get_activation_root ();
        return (file != null && file.get_uri ().has_prefix ("gphoto2://"));
    }

    private bool check_for_external_device (Drive drive) {
        string ? unix_device = drive.get_identifier ("unix-device");
        stdout.printf ("%s\n", unix_device);
        return (drive.is_media_removable () || drive.can_stop ()) && (unix_device != null && (unix_device.has_prefix ("/dev/sd") || unix_device.has_prefix ("/dev/mmc")));
    }
}