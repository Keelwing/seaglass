// Stub for the QML check: Sailfish.Weather comes with the Weather app from the Jolla Store
import QtQuick 2.6

ListModel {
    property bool active
    property var weather
    property var savedWeathers
    property var timestamp
    property int status
    signal requestFinished()
}
