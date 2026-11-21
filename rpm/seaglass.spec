# seaglass: noarch package for Sailfish OS, built by rpm/build.sh in the tool image from the staged
# tree in SOURCES/root. QML and a Patchmanager patch: no SDK needed.
Name:       seaglass
Version:    %{seaglass_version}
Release:    %{?seaglass_release}%{!?seaglass_release:1}
Summary:    Home screen extensions for Sailfish OS: widgets, glass, search, badges and a richer switcher
License:    GPL-3.0-or-later
URL:        https://github.com/Keelwing/seaglass
BuildArch:  noarch

# Only the Sailfish packages it uses; no dependencies from the build host
AutoReqProv: no
Requires:   lipstick-jolla-home-qt5
Requires:   sailfishsilica-qt5
Requires:   patchmanager >= 3.2
# the settings' list of ambience pictures (Qt.labs.folderlistmodel)
Requires:   qt5-qtdeclarative-import-folderlistmodel

# Sailfish OS 5.2 has rpm 4.16: gzip payload; none of the build host's post-install processing
%define _binary_payload w9.gzdio
%define _source_payload w9.gzdio
%define __os_install_post %{nil}
%define _build_id_links none

# Patchmanager's D-Bus service: apply, unapply and ask about the patch from the scriptlets
%define pm_call dbus-send --system --print-reply --reply-timeout=15000 --dest=org.SfietKonstantin.patchmanager /org/SfietKonstantin/patchmanager org.SfietKonstantin.patchmanager
%define pm_state /var/lib/rpm-state/%{name}-applied
%define pm_patches /usr/share/patchmanager/patches
%define patch_dir %{pm_patches}/%{name}
%define diffs /usr/share/%{name}/diffs

%description
Extensions of the stock Sailfish OS home screen, each one a setting:
- folder previews, and folders shown as widgets (a card, a shelf or a panel) that move in the app grid;
- folder open and close motions;
- the app grid as a pane of glass over the home screen's wallpaper;
- app search with the apps used most and an A-Z list;
- notification badges on icons, with a peek on a long press;
- task switcher name chips, recently closed apps, a card row and a pinch between grid and cards;
- data widgets: a clock, the battery and connections, now playing, the next events and the weather.

The QML lives in /usr/share/seaglass. A Patchmanager patch ("Seaglass") loads it into the home screen,
and the stock home screen stays whenever it cannot be loaded. Activate the patch in Settings > Patchmanager;
tap it there for its settings. Remove with: rpm -e seaglass

%prep

%build

%install
mkdir -p %{buildroot}
cp -a %{_sourcedir}/root/. %{buildroot}/

%pre
# An update: remember whether the patch is active, and take the old hook out of the home screen first (a state file
# left by a failed transaction must not activate a fresh install)
rm -f %{pm_state}
if [ "$1" -gt 1 ]; then
    if %{pm_call}.isPatchApplied string:%{name} 2>/dev/null | grep -q "boolean true"; then
        mkdir -p "$(dirname %{pm_state})" && touch %{pm_state}
        %{pm_call}.unapplyPatch string:%{name} >/dev/null 2>&1 || :
    fi
fi

%post
# The hook of this phone's Sailfish OS series (5.2.0.20 -> diffs/5.2.patch): Patchmanager reads one diff per patch
series=$(sed -n 's/^VERSION_ID=//p' /etc/sailfish-release 2>/dev/null | tr -d '"' | cut -d. -f1,2)
if [ -n "$series" ] && [ -f %{diffs}/$series.patch ]; then
    cp %{diffs}/$series.patch %{patch_dir}/unified_diff.patch
else
    : > %{patch_dir}/unified_diff.patch
    echo "seaglass: this package has no hook for Sailfish OS ${series:-(unknown)}."
fi
# Patchmanager learns which files a patch changes from its diff, when it starts and when an entry of the patches
# folder comes or goes. The folder came before the diff above, so show Patchmanager a change: an entry it does not
# take for a patch (a hidden folder), made and taken away. Without this, a fresh install cannot be activated.
mkdir %{pm_patches}/.%{name}-reload 2>/dev/null && rmdir %{pm_patches}/.%{name}-reload || :
# droid-config-* owns /etc/ld.so.preload, and an OS update replaces it without Patchmanager's line
if ! grep -q libpreloadpatchmanager /etc/ld.so.preload 2>/dev/null; then
    echo "seaglass: WARNING: Patchmanager's preload is missing from /etc/ld.so.preload, so no patch reaches"
    echo "the home screen. See Troubleshooting in /usr/share/doc/seaglass/README.md."
fi

%preun
# Removal (not an update): take the hook out of the home screen first; a hook left behind only loses our part
if [ "$1" -eq 0 ]; then
    %{pm_call}.unapplyPatch string:%{name} >/dev/null 2>&1 || :
fi

%posttrans
# An update of an active patch: activate the new hook again
if [ -e %{pm_state} ]; then
    rm -f %{pm_state}
    if %{pm_call}.applyPatch string:%{name} >/dev/null 2>&1; then
        echo "seaglass: the patch is active again; restart the home screen to load the new version."
    else
        echo "seaglass: activate 'Seaglass' again in Settings > Patchmanager."
    fi
else
    echo "seaglass: activate 'Seaglass' in Settings > Patchmanager, then restart the home screen when"
    echo "Patchmanager asks."
fi

%files
%defattr(-,root,root,-)
%license /usr/share/licenses/seaglass/LICENSE
/usr/share/seaglass
%dir %{patch_dir}
%{patch_dir}/patch.json
%{patch_dir}/main.qml
%{patch_dir}/main.svg
%{patch_dir}/main-light.svg
# written by %post: the diff of the phone's series
%ghost %{patch_dir}/unified_diff.patch
%doc /usr/share/doc/seaglass/README.md
%doc /usr/share/doc/seaglass/CHANGELOG.md

%changelog
* Sat Nov 21 2026 Syrtis Major <d31m05z@gmail.com> - 1.1.1-1
- Patchmanager's page of the patch: the app animations in the description, and the support link.

* Sun Nov 08 2026 Syrtis Major <d31m05z@gmail.com> - 1.1.0-1
- App animations: a page that shows every style as stills, three Paper styles, effects on the render thread and
  Surprise me by default; data widgets keep their places; Sailfish OS 5.2.0.22.

* Sat Oct 17 2026 Syrtis Major <d31m05z@gmail.com> - 1.0.0-1
- First public release: folder previews and folders as widgets, folder motion, glass, app search, notification
  badges, a richer task switcher and data widgets, with its settings in Patchmanager.
