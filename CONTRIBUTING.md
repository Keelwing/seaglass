# Contributing

Bug reports, reports from phones and Sailfish OS versions I don't have, and pull requests are all welcome.

## Reporting a problem

Open an issue with the bug report form. It asks for the Sailfish OS version, the phone, and the versions of Seaglass
and Patchmanager. Two things help most:
- what the first page of Seaglass's settings says (the status line at the top);
- the journal lines with *Debug log* on (About page): `devel-su journalctl -b | grep seaglass:`. They never
  hold the text of a notification, but they can name apps and accounts, so look through them before you post.

If you run the testers' package on Sailfish OS 5.1 or 5.0, the "Older Sailfish OS" form is the place to say how it
went, good or bad. Those versions move into `patch.json` once someone has run them on a phone.

## Changing the code

[docs/DEVELOPMENT.md](docs/DEVELOPMENT.md) covers the setup, the make targets and the harness, and
[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) how the hook and the QML fit together. In short:
- Lipstick runs Qt 5.6: `import QtQuick 2.6` at most, and ES5 JavaScript only.
- Each feature has its folder in `qml/`; other folders are imported by relative path.
- A part that fails to load must leave that part of the home screen stock.
- Every new behaviour is a setting, with a default that keeps the stock behaviour or something close to it.
- Nothing goes to the journal unless *Debug log* is on.
- Jolla's stock files stay in `out/` and are never committed. Screenshots come from the harness's public mode, never
  from a phone with its own wallpaper, apps or data.

Before a pull request, run `make test lint`, and `make check-hooks` when the hook changed. CI runs the same targets,
and compiles the QML with the 5.1 and 5.0 SDK targets. Anything that changes what the home screen does needs a test
on a phone: say in the pull request which phone and Sailfish OS version you tried it on.

Keep commits small, with a short message in the imperative.

## Code of conduct

Everyone taking part in the issues and pull requests follows the [code of conduct](CODE_OF_CONDUCT.md).

## License

Contributions are under the [GNU GPL, version 3 or later](LICENSE), like the rest of the code.
