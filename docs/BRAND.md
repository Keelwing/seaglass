# Seaglass

This note covers Seaglass's name, its colours, the motif, the icon and the Patchmanager glyph.

## The name

Sea glass is glass that the sea has tumbled smooth and frosted. Frosted glass is what people notice first on this
home screen: the app grid, the folders, the widgets and the search all sit on it. The name also keeps to the sea of
Sailfish OS, where Sailfish, Harbour and Jolla itself (a small boat, in Finnish) come from.

It is one word, easy to say in English and in Finnish, and it works as a package name. A search of OpenRepos, Chum,
the Sailfish forum and the Jolla store found no app called Seaglass (October 2026).

It is written *Seaglass*, one word with a capital S. The package, the paths and the settings use `seaglass`. The
one-line description stays plain: "Home screen extensions for Sailfish OS".

## Colours

| Name | Value | Where |
|---|---|---|
| Aqua | `#7FF0D8` | the light end of the icon's background |
| Teal | `#14A39A` | the middle of the background; links and focus on the site |
| Deep teal | `#0F6E63` | lines and text on frosted glass |
| Cobalt | `#1A3C8F` | the dark end of the background; the site's background |
| Frost | `#F3FBF9` | the phone, and frosted glass |
| Ember | `#FFD38A` → `#FF9A5C` → `#F2575F` | the plus, and the site's download button, nothing else |

Ember is a warm piece of sea glass among the cool ones. Keeping it for the plus is what makes the plus stand out.

On the phone nothing changes: the home screen keeps taking its colours from the ambience. The palette is for the
icon, the glyph, the site and the GitHub preview.

## The motif

A piece of the interface lifted out of the phone. A glass card rises from the screen and past the phone's edge, and a
tumbled piece of warm sea glass carries a plus. It says what Seaglass is: the home screen you already have, with more
on it. The icon, the site's first screen and the GitHub preview all use it.

## The icon

`icons/seaglass.svg`, a 256 × 256 view box, drawn like a Sailfish app icon:
- **Shape.** Sailfish's launcher shape, a circle whose bottom left quarter is square.
- **Background.** Aqua at the top right to teal to cobalt at the bottom left, a soft light at the top right, and two
  faint waves along the bottom.
- **The phone.** Frost white with a soft shadow. Its screen shows the home screen with Seaglass on it: a shelf of
  chips, a few app icons and the bottom row.
- **The card.** A frosted clock card lifted out of the screen, turned 8°, past the phone's right edge.
- **The plus.** The ember pebble at the bottom right, over the phone's corner, with a white plus.

`make icons` renders `seaglass-200.png` for the releases. The README and the site use the SVG. The icon has to read at
86 px, the launcher's size on the Jolla Phone, and it does.

## The Patchmanager glyph

The same drawing in one colour, at 72 px in Patchmanager's list:
- the phone as an outline, with two rows of app icons;
- the card coming out of it, with its two lines cut out;
- the pebble with the plus cut out.

`patchmanager/main.svg` is white, for dark ambiences, and `main-light.svg` is black, for light ones. Patchmanager
draws them with Qt's SVG renderer, which has no masks and no filters. So the cut-outs are holes in the paths
(`fill-rule="evenodd"`), and the outline stops short of the card instead of being covered by it.

## The site and the README

- **README.** The title becomes *Seaglass*, with the icon at its top right.
- **Site.** This palette: a cobalt to deep teal background, teal and aqua for links and focus, and ember for the
  download button. The first screen keeps its phone,
  with a glass card lifting out of it as in the icon.
- **GitHub preview.** The icon, the name and the description over the background gradient, 1280 × 640.
  `make icons` renders it to `out/icons/seaglass-social.png`, to upload by hand in the repository's settings.
