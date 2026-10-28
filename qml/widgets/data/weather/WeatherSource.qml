// The Weather widget's source (docs/WIDGETS.md): the Weather app's current location and its forecasts, through
// Sailfish.Weather, as the Events view's banner (Sailfish/Weather/WeatherBanner.qml): SavedWeathersModel (the saved
// file, which the app and the Events view update too), WeatherModel (the current weather) and WeatherForecastModel
// (hourly and daily). We refresh only while the grid is shown, under the stock rules (the current weather and the
// hourly forecast at most every 30 minutes, the daily one every 3 hours) and through the stock response cache. The
// stock models also reload by themselves when the network comes back or after an error, as they do for the Events view.
// Loaded by DataSources.qml; without the Weather app's module, Weather is not offered.
//   live       the app grid is on screen
//   demo       sample values (the harness): a made-up place, never the phone's locations
//   demoState  with "none": no location set up; with "stale": the weather is five hours old
//   hourly     the hourly forecast is wanted (the daily one always is: today's high and low)
import QtQuick 2.6
import Sailfish.Weather 1.0
import Nemo.Time 1.0
import Nemo.Configuration 1.0

// an Item, not a QtObject: Qt 5's Loader does not load non-visual root objects
Item {
    id: weatherSource

    property bool live: true
    property bool demo
    property string demoState
    property bool hourly: true

    // the phone's weather models (the Instantiator's object below), never made in the harness: no one's places in a
    // sample, and no request for them
    property QtObject parts: null
    readonly property QtObject current: parts ? parts.current : null
    // a location is set up and has its weather
    readonly property bool ready: demo ? demoState.indexOf("none") < 0
                                       : !!current && current.populated && WeatherProvider.isLocationCompatible(current)
    readonly property string city: demo ? "Helsinki" : current ? current.city : ""
    readonly property string description: demo ? "Partly cloudy" : current ? current.description : ""
    readonly property string weatherType: demo ? "d200" : current ? current.weatherType : ""
    readonly property var temperature: demo ? 14 : current ? current.temperature : 0
    readonly property var feelsLike: demo ? 12 : current ? current.feelsLikeTemperature : 0
    readonly property date updated: demo ? new Date(now.getTime() - (demoState.indexOf("stale") >= 0 ? 5 : 0.5) * 3600 * 1000)
                                         : current ? current.timestamp : new Date(NaN)
    readonly property date now: demo ? new Date(2026, 9, 15, 9, 41) : wallClock.time
    // the 12 or 24 hour clock, as the stock clock (for the forecast's hours)
    readonly property bool twentyFour: demo ? true : timeFormat.value === "24"
    // [{time, weatherType, temperature}] and [{time, weatherType, high, low}], from the time and the day of the fetch
    readonly property var hours: demo ? demoHours() : hourlyList
    readonly property var daysAhead: demo ? demoDays() : dailyList
    readonly property bool hasFeelsLike: feelsLike !== undefined && feelsLike !== null && feelsLike !== ""
    // the provider's small logo, coloured on use (append a colour), or ""
    readonly property string providerImage: WeatherProvider.smallProviderImage()

    property var hourlyList: []
    property var dailyList: []
    // a turn after loading: DataSources.qml sets demo once the source is made, so the models wait for it
    property bool started

    visible: false

    // the current weather was fetched since the last save
    property bool fetched

    // as the Events view's banner: what was fetched goes into the saved file when the grid goes away (only then, so
    // that hiding the grid writes nothing)
    onLiveChanged: {
        if (!live && parts && fetched) {
            parts.save()
            fetched = false
        }
    }

    Timer {
        interval: 0
        running: true
        onTriggered: weatherSource.started = true
    }

    function format(temperature) {
        return TemperatureConverter.format(temperature)
    }

    function demoHours() {
        var types = ["d200", "d300", "d310", "d210", "d100", "d100"]
        var temps = [14, 15, 13, 12, 12, 11]
        var list = []
        for (var i = 0; i < types.length; i++) {
            var t = new Date(now.getTime())
            t.setMinutes(0, 0, 0)
            t.setHours(t.getHours() + i + 1)
            list.push({ "time": t, "weatherType": types[i], "temperature": temps[i] })
        }
        return list
    }

    function demoDays() {
        var types = ["d200", "d310", "d400", "d100", "d000", "d210"]
        var highs = [16, 13, 11, 14, 17, 15]
        var lows = [8, 7, 6, 5, 7, 9]
        var list = []
        for (var i = 0; i < types.length; i++) {
            var t = new Date(now.getFullYear(), now.getMonth(), now.getDate() + i, 12)
            list.push({ "time": t, "weatherType": types[i], "high": highs[i], "low": lows[i] })
        }
        return list
    }

    function read(model, daily) {
        var list = []
        for (var i = 0; model && i < model.count; i++) {
            var row = model.get(i)
            if (daily)
                list.push({ "time": row.timestamp, "weatherType": row.weatherType || "", "high": row.high, "low": row.low })
            else
                list.push({ "time": row.timestamp, "weatherType": row.weatherType || "", "temperature": row.temperature })
        }
        return list
    }

    ConfigurationValue {
        id: timeFormat

        key: "/sailfish/i18n/lc_timeformat24h"
    }

    WallClock {
        id: wallClock

        enabled: weatherSource.live && !weatherSource.demo
        updateFrequency: WallClock.Minute
    }

    // The models, as the Events view's banner has them. In this delegate a model's own properties come before the
    // file's ids: the root is named weatherSource, which no model has (WeatherModel has a source)
    Instantiator {
        model: weatherSource.started && !weatherSource.demo ? 1 : 0

        QtObject {
            readonly property QtObject current: saved.currentWeather

            function save() {
                saved.save()
            }

            property list<QtObject> models: [
                SavedWeathersModel {
                    id: saved

                    autoRefresh: true
                    provider: WeatherProvider.currentProvider()
                },

                // the current weather: requested when the grid shows, if allowed (WeatherModel: the 30 minutes rule)
                WeatherModel {
                    id: weatherModel

                    active: weatherSource.live
                    weather: saved.currentWeather
                    savedWeathers: saved
                    onRequestFinished: weatherSource.fetched = true
                },

                WeatherForecastModel {
                    id: daily

                    hourly: false
                    active: weatherSource.live
                    weather: saved.currentWeather
                    timestamp: weatherModel.timestamp
                    onCountChanged: weatherSource.dailyList = weatherSource.read(daily, true)
                    onStatusChanged: weatherSource.dailyList = weatherSource.read(daily, true)
                },

                WeatherForecastModel {
                    id: hourlyModel

                    hourly: true
                    active: weatherSource.live && weatherSource.hourly
                    weather: saved.currentWeather
                    timestamp: weatherModel.timestamp
                    onCountChanged: weatherSource.hourlyList = weatherSource.read(hourlyModel, false)
                    onStatusChanged: weatherSource.hourlyList = weatherSource.read(hourlyModel, false)
                }
            ]
        }

        onObjectAdded: weatherSource.parts = object
        onObjectRemoved: weatherSource.parts = null
    }
}
