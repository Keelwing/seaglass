// The status widget's source (docs/WIDGETS.md): the battery and the connections, from the objects the status bar and
// the top menu's switches use (BatteryStatus, McePowerSaveMode, Connman's technologies and manager, BluetoothStatus).
// Loaded by DataSources.qml; when a module is missing, the status widget is not offered.
//   demo   sample values (the harness)
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

    readonly property bool wifiOn: demo ? true : wifi.powered
    readonly property bool wifiConnected: demo ? true : wifi.connected
    readonly property string wifiName: demo ? "Home" : (manager.connectedWifi ? manager.connectedWifi.name : "")
    readonly property bool mobileOn: demo ? true : cellular.powered
    readonly property bool mobileConnected: demo ? false : cellular.connected
    readonly property bool bluetoothOn: demo ? true : (bluetoothTechnology.powered && bluetooth.powered)
    readonly property bool bluetoothConnected: demo ? false : bluetooth.connected
    readonly property var bluetoothDevices: demo ? [] : (bluetooth.connectedDeviceNames || [])
    readonly property bool flight: demo ? false : manager.offlineMode

    visible: false

    BatteryStatus {
        id: battery
    }

    McePowerSaveMode {
        id: powerSaveMode
    }

    NetworkManager {
        id: manager
    }

    NetworkTechnology {
        id: wifi

        path: Connman.wifiTechnologyPath
    }

    NetworkTechnology {
        id: cellular

        path: Connman.cellularTechnologyPath
    }

    NetworkTechnology {
        id: bluetoothTechnology

        path: Connman.bluetoothTechnologyPath
    }

    BluetoothStatus {
        id: bluetooth
    }

    function switchWifi() {
        if (demo || !AccessPolicy.wlanToggleEnabled || wifi.tethering)
            return false
        wifi.powered = !wifi.powered
        return true
    }

    function switchBluetooth() {
        if (demo || !AccessPolicy.bluetoothToggleEnabled)
            return false
        bluetoothTechnology.powered = !bluetoothTechnology.powered
        return true
    }

    function switchFlight() {
        if (demo || !AccessPolicy.flightModeToggleEnabled)
            return false
        manager.offlineMode = !manager.offlineMode
        return true
    }
}
