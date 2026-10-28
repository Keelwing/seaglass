// The status widget's source (docs/WIDGETS.md): the battery and the connections, from the objects the status bar and
// the top menu's switches use (BatteryStatus, McePowerSaveMode, Connman's technologies and manager, BluetoothStatus).
// Loaded by DataSources.qml; when a module is missing, the status widget is not offered.
//   demo   sample values (the harness): a made-up network, never the phone's
// Switching follows the top menu's switches (/usr/share/jolla-settings/pages/*/EnableSwitch.qml, WlanSwitch.qml,
// flight/FlightMode.qml): the device policy first, then the same property. A switch that cannot be made here returns
// false, and the widget opens the settings page instead.
import QtQuick 2.6
import org.nemomobile.systemsettings 1.0
import Connman 0.2
import Nemo.Mce 1.0
import Sailfish.Lipstick 1.0
import Sailfish.Policy 1.0

Item {
    id: source

    property bool live: true
    property bool demo

    // the charge in percent, or -1 when unknown
    readonly property int percent: demo ? 72 : battery.chargePercentage
    readonly property bool charging: demo ? false : battery.chargerStatus === BatteryStatus.Connected
    readonly property bool low: demo ? false : (battery.status === BatteryStatus.Low
                                                || battery.status === BatteryStatus.Empty)
    readonly property bool powerSave: demo ? false : powerSaveMode.active

    readonly property bool wifiOn: demo ? true : !!network && network.wifi.powered
    readonly property bool wifiConnected: demo ? true : !!network && network.wifi.connected
    readonly property string wifiName: demo ? "Home" : network && network.manager.connectedWifi
                                                       ? network.manager.connectedWifi.name : ""
    readonly property bool mobileOn: demo ? true : !!network && network.cellular.powered
    readonly property bool mobileConnected: demo ? false : !!network && network.cellular.connected
    readonly property bool bluetoothOn: demo ? true : !!network && network.bluetoothPower.powered
                                                      && network.bluetooth.powered
    readonly property bool bluetoothConnected: demo ? false : !!network && network.bluetooth.connected
    readonly property var bluetoothDevices: demo || !network ? [] : (network.bluetooth.connectedDeviceNames || [])
    readonly property bool flight: demo ? false : !!network && network.manager.offlineMode

    // Connman's and Bluetooth's objects (the Instantiator's object below), never made in the harness: no one's
    // networks or devices in a sample
    property QtObject network: null
    // a turn after loading: DataSources.qml sets demo once the source is made, so the objects wait for it
    property bool started

    visible: false

    BatteryStatus {
        id: battery
    }

    McePowerSaveMode {
        id: powerSaveMode
    }

    Timer {
        interval: 0
        running: true
        onTriggered: source.started = true
    }

    Instantiator {
        model: source.started && !source.demo ? 1 : 0

        QtObject {
            readonly property QtObject manager: networkManager
            readonly property QtObject wifi: wifiTechnology
            readonly property QtObject cellular: cellularTechnology
            readonly property QtObject bluetoothPower: bluetoothTechnology
            readonly property QtObject bluetooth: bluetoothStatus

            property list<QtObject> objects: [
                NetworkManager {
                    id: networkManager
                },

                NetworkTechnology {
                    id: wifiTechnology

                    path: Connman.wifiTechnologyPath
                },

                NetworkTechnology {
                    id: cellularTechnology

                    path: Connman.cellularTechnologyPath
                },

                NetworkTechnology {
                    id: bluetoothTechnology

                    path: Connman.bluetoothTechnologyPath
                },

                BluetoothStatus {
                    id: bluetoothStatus
                }
            ]
        }

        onObjectAdded: source.network = object
        onObjectRemoved: source.network = null
    }

    function switchWifi() {
        if (demo || !network || !AccessPolicy.wlanToggleEnabled || network.wifi.tethering)
            return false
        network.wifi.powered = !network.wifi.powered
        return true
    }

    function switchBluetooth() {
        if (demo || !network || !AccessPolicy.bluetoothToggleEnabled)
            return false
        network.bluetoothPower.powered = !network.bluetoothPower.powered
        return true
    }

    function switchFlight() {
        if (demo || !network || !AccessPolicy.flightModeToggleEnabled)
            return false
        network.manager.offlineMode = !network.manager.offlineMode
        return true
    }
}
