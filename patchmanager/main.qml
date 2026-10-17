// The settings of the Seaglass patch (Settings > Patchmanager > Seaglass), pushed by Patchmanager when the patch is
// tapped. The pages live with the rest of Seaglass, in /usr/share/seaglass/qml/settings/.
import QtQuick 2.6
import Sailfish.Silica 1.0
import "file:///usr/share/seaglass/qml/settings/"

Page {
    id: page

    allowedOrientations: Orientation.All

    SettingsHub {
        anchors.fill: parent
        // scripts/harness.sh's copy sets this: no D-Bus calls from the harness
        inHarness: false
    }
}
