# Changelog

Each version was checked on a Jolla Phone with the newest Sailfish OS it lists. How each feature works is in
[docs/](docs/).

## Unreleased

- App animations are on out of the box: apps open in Ember, load in Dust and close in Northern lights, at the quick
  speed and in the ambience's colours.
- After an update from 1.0.0, a style picked there with a tile plays only for the moments that were set to *Same as
  style*. The other moments take the new defaults until you choose again.
- Surprise me covers every moment that is not set to Stock.
- The Animations page shows every style's opening, loading and closing at once as still frames. A tap plays one
  large, with its whole run as a strip you can drag. Looking changes nothing until you tap Use.
- Three new styles in a new group, Paper: Contour, Fold and Halftone.
- Fire, sparks, stars and lightning move while an app opens or closes, and frosted glass has a fine grain instead of
  square blocks.
- The nine styles of 1.0.0 were reworked to look more like what they are made of, and none of them ends early or
  jumps at its start or end.
- Removing a data widget, restoring the starter widgets or going back to an older Seaglass no longer moves the other
  widgets away from their apps.
- After a backup is restored, every widget shows the kind it was saved with.
- A widget whose kind is missing on the phone shows only "Not available on this phone", in the gallery too.
- Now playing no longer says "Nothing playing" for a paused player that just appeared, or after a track change.
- Weather: today's high and low and the "Today" column stay right after midnight. With *By size*, the hourly forecast
  is fetched only while a weather shelf is on the grid or in the gallery.
- Next event: "Tomorrow" is right on the days the clocks change.
- Sailfish OS 5.2.0.22.

## 1.0.0 (2026-10-17)

The first public release.

- Folders show small icons of their apps. A folder can also sit on the app grid as a card, a shelf or a panel, which
  moves and changes size in the edit mode like an icon.
- Folders open from their icon or card and close back into it: zoom, spring, reveal or slide, with the apps rippling
  in.
- Glass: the app grid rises over the home screen's wallpaper, sharp or frosted, with parallax and depth, and
  optional tilt and drift. A picture of another ambience, or a photo, can take the wallpaper's place under the grid.
  Folder icons, open folders and widget cards are glass too.
- Search: a capsule on the app grid's first page with the apps you use most, and a sheet that finds any app or folder
  as you type, or lists them A to Z with a letter rail.
- Notification badges on app icons, folders, cards and the search, as counts or dots. A long press on an app or a
  folder with a badge shows its notifications, with the edit mode a tap away.
- Task switcher: names under the covers, the apps closed last in a row of their own, an optional row of cards where a
  card pulled up closes its app, and a pinch between the grid and the cards.
- Data widgets: a clock, the battery and connections, what is playing, the next events and the weather, added from
  the edit mode. A fresh install starts with the clock and the status, and a hint shows once how to edit the grid.
- App animations: apps open from the icon or cover you tapped, load on their new cover and close with the swipe from
  the top in one of nine styles, from calm glass, water and light to fire, lightning, ice and loud ones that shatter
  or swallow the app. A style per moment, or a surprise each time, set up on a page with a live preview. Off by
  default.
- Settings: a first page that says whether Seaglass runs, and if not, why and what to do; a page per feature with
  live previews; a reset; a backup of the settings, widgets and folder types to Documents; and a link to support
  Seaglass on Ko-fi.
- Sailfish OS 5.2.0.18 and 5.2.0.20. Each release also has a testers' package for 5.1 and 5.0, which CI checks but
  which has not run on such a phone yet.
