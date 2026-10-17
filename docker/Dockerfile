# syntax=docker/dockerfile:1
#
# Tool image for scripts/*.sh: builds the noarch RPM (rpmbuild), applies the hook like Patchmanager does (GNU
# patch), checks QML syntax (qmllint for Qt 5; the phone runs Qt 5.6) and the shell scripts (shellcheck), turns
# the harness's frames into GIFs and screenshots (ImageMagick), renders the icon and the GitHub preview (rsvg-convert,
# with the site's font through fontTools and fontconfig), builds the GitHub Pages site from the Markdown docs
# (Python-Markdown), and unpacks Jolla's stock packages (bsdtar).
# Nothing here is installed on the phone.
FROM debian:trixie
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
 && apt-get install -y --no-install-recommends rpm python3 patch qtdeclarative5-dev-tools shellcheck imagemagick \
    librsvg2-bin python3-markdown libarchive-tools ca-certificates fontconfig python3-fonttools python3-brotli \
 && rm -rf /var/lib/apt/lists/*
ENV PATH=/usr/lib/qt5/bin:$PATH
