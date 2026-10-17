# Security

Seaglass runs inside the home screen, which has the `privileged` group, so a flaw in it matters. Some facts that
limit what it can do:
- The hook loads QML only from `/usr/share/seaglass`, which the package installs as root. It never loads QML
  from the home directory.
- Seaglass makes no network requests of its own. The weather widget uses the stock weather module.
- It stores its settings in dconf, under `/apps/seaglass`, on the phone only.

## Reporting a vulnerability

Please don't open a public issue for it. Use GitHub's private reporting instead: *Security → Report a
vulnerability* on this repository.

Fixes go into the latest release only.
