# Home screen extensions for Sailfish OS. `make help` lists the targets.
.DEFAULT_GOAL := help
# make hook VERSION=5.1.0.11: a release's stock files, downloaded, instead of the phone's
VERSION ?=
# make qml-check TARGET=5.1.0.11: only that SDK target
TARGET ?=
# make rpm CHANNEL=preview: the testers' package, with the versions only CI has checked
CHANNEL ?= release
export CHANNEL
.PHONY: help test lint hook check-hook check-hooks qml-check harness screenshots icons site status journal rpm release deploy install remove clean

help:
	@echo "Development (no root on the phone):"
	@echo "  make test        unit tests (hook, repository consistency)"
	@echo "  make lint        qmllint, shellcheck, actionlint (Docker)"
	@echo "  make harness     draw the folder previews on the phone with this tree's QML -> out/shots/harness.png"
	@echo "  make hook        regenerate the hook of the phone's Sailfish OS series (patchmanager/diffs/)"
	@echo "                   (VERSION=5.1.0.11: that release's stock files, downloaded from Jolla, no phone)"
	@echo "  make check-hook  check the hook against the phone's home screen (dry run, qmllint; VERSION= as above)"
	@echo "  make check-hooks check the hook against every version in patchmanager/versions (no phone)"
	@echo "  make qml-check   compile our QML with older Sailfish OS releases' Qt and Silica (SDK targets, Docker)"
	@echo "                   (TARGET=5.1.0.11: only that one)"
	@echo "  make screenshots the public screenshots (stock apps, stock ambience) -> docs/images/"
	@echo "  make icons       the 200 px icon -> out/icons/seaglass-200.png"
	@echo "  make site        the GitHub Pages site -> out/site/ (the landing page, the docs, the images)"
	@echo "Package:"
	@echo "  make rpm         out/rpm/seaglass-VERSION-1.noarch.rpm (Docker; CHANNEL=preview: the testers')"
	@echo "  make release     out/release/vVERSION: the package, the 200 px icon, SHA256SUMS, the notes"
	@echo "                   (a pushed tag vVERSION publishes it on GitHub: .github/workflows/release.yml)"
	@echo "  make deploy      copy it to the phone (~/seaglass)"
	@echo "  make install     rpm -U on the phone (asks for the devel-su password)"
	@echo "  make remove      rpm -e on the phone (asks for the devel-su password)"
	@echo "  make status      why the preview is (not) on the home screen (read-only checks on the phone)"
	@echo "  make journal     the home screen's QML messages of this boot (asks for the devel-su password)"

test:
	python3 -I -m unittest discover -s tests -v

lint:
	scripts/lint.sh

hook:
	scripts/hook.sh $(VERSION)

check-hook:
	scripts/check-hook.sh $(VERSION)

check-hooks:
	scripts/check-hooks.sh

qml-check:
	scripts/qml-check.sh $(TARGET)

harness:
	scripts/harness.sh --shot harness

screenshots:
	scripts/screenshots.sh

icons:
	scripts/icons.sh

site:
	scripts/site.sh

status:
	scripts/status.sh

journal:
	scripts/journal.sh

rpm:
	scripts/rpm.sh

release:
	scripts/release.sh

deploy:
	scripts/deploy.sh

install:
	scripts/install.sh

remove:
	scripts/install.sh --remove

clean:
	rm -rf out/rpm out/check-hook out/shots out/icons out/release out/site
