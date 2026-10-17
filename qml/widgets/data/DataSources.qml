// The data widgets' sources (docs/WIDGETS.md): one per kind, shared by all its widgets, loaded only while a widget of
// that kind exists (or the gallery shows it). Each source is a file of its own in a Loader, so that a missing module
// makes only its kind unavailable.
//   wanted      {kind: true} for the kinds to load
//   live        the app grid is on screen and the display is on: the sources tick only then
//   demo        sample values (the harness: no one's events, places or music in a screenshot)
//   demoState   the harness's other sample states, as words: idle (player), empty (events), none or stale (weather)
//   eventDays, eventAllDay, weatherHourly   the settings the sources query with
import QtQuick 2.6

Item {
    id: sources

    property var wanted: ({})
    property bool live: true
    property bool demo
    property string demoState
    property int eventDays: 6
    property bool eventAllDay: true
    property bool weatherHourly: true

    readonly property Item clock: clockLoader.item
    readonly property Item status: statusLoader.item
    readonly property Item player: playerLoader.item
    readonly property Item event: eventLoader.item
    readonly property Item weather: weatherLoader.item

    visible: false

    function loaderOf(kind) {
        return kind === "clock" ? clockLoader : kind === "status" ? statusLoader : kind === "player" ? playerLoader
             : kind === "event" ? eventLoader : kind === "weather" ? weatherLoader : null
    }

    function sourceOf(kind) {
        var loader = loaderOf(kind)
        return loader ? loader.item : null
    }

    // the kind's module could not be loaded on this phone
    function failed(kind) {
        var loader = loaderOf(kind)
        return !loader || loader.status === Loader.Error
    }

    function bind(item) {
        item.live = Qt.binding(function () { return sources.live })
        item.demo = Qt.binding(function () { return sources.demo })
        if (item.demoState !== undefined)
            item.demoState = Qt.binding(function () { return sources.demoState })
    }

    Loader {
        id: clockLoader

        active: sources.wanted.clock === true
        source: "clock/ClockSource.qml"
        onLoaded: sources.bind(item)
    }

    Loader {
        id: statusLoader

        active: sources.wanted.status === true
        source: "status/StatusSource.qml"
        onLoaded: sources.bind(item)
    }

    Loader {
        id: playerLoader

        active: sources.wanted.player === true
        source: "player/PlayerSource.qml"
        onLoaded: sources.bind(item)
    }

    Loader {
        id: eventLoader

        active: sources.wanted.event === true
        source: "event/EventSource.qml"
        onLoaded: {
            sources.bind(item)
            item.days = Qt.binding(function () { return sources.eventDays })
            item.allDay = Qt.binding(function () { return sources.eventAllDay })
        }
    }

    Loader {
        id: weatherLoader

        active: sources.wanted.weather === true
        source: "weather/WeatherSource.qml"
        onLoaded: {
            sources.bind(item)
            item.hourly = Qt.binding(function () { return sources.weatherHourly })
        }
    }
}
