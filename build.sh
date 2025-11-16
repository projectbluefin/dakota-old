#!/usr/bin/env bash

set -xeuo pipefail

cp -avf "/tmp/ctx/files"/. /

wget -O /usr/share/homebrew.tar.zst "https://github.com/ublue-os/packages/releases/download/homebrew-2025-11-11-01-29-58/homebrew-$(arch).tar.zst"

# wallpaper needs whatever
# jetbrains font?

# # Install tooling
# dnf5 -y install glib2-devel meson sassc cmake dbus-devel

# AppIndicator Support
glib-compile-schemas --strict /usr/share/gnome-shell/extensions/appindicatorsupport@rgcjonas.gmail.com/schemas

# Blur My Shell
# make -C /usr/share/gnome-shell/extensions/blur-my-shell@aunetx
# unzip -o /usr/share/gnome-shell/extensions/blur-my-shell@aunetx/build/blur-my-shell@aunetx.shell-extension.zip -d /usr/share/gnome-shell/extensions/blur-my-shell@aunetx
# glib-compile-schemas --strict /usr/share/gnome-shell/extensions/blur-my-shell@aunetx/schemas
# rm -rf /usr/share/gnome-shell/extensions/blur-my-shell@aunetx/build

# Caffeine
# The Caffeine extension is built/packaged into a temporary subdirectory (tmp/caffeine/caffeine@patapon.info).
# Unlike other extensions, it must be moved to the standard extensions directory so GNOME Shell can detect it.
mv /usr/share/gnome-shell/extensions/tmp/caffeine/caffeine@patapon.info /usr/share/gnome-shell/extensions/caffeine@patapon.info
glib-compile-schemas --strict /usr/share/gnome-shell/extensions/caffeine@patapon.info/schemas

# Dash to Dock
# make -C /usr/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com
# glib-compile-schemas --strict /usr/share/gnome-shell/extensions/dash-to-dock@micxgx.gmail.com/schemas

# GSConnect (commented out until G49 support)
# meson setup --prefix=/usr /usr/share/gnome-shell/extensions/gsconnect@andyholmes.github.io /usr/share/gnome-shell/extensions/gsconnect@andyholmes.github.io/_build
# meson install -C /usr/share/gnome-shell/extensions/gsconnect@andyholmes.github.io/_build --skip-subprojects
# GSConnect installs schemas to /usr/share/glib-2.0/schemas and meson compiles them automatically

# Logo Menu
# xdg-terminal-exec is required for this extension as it opens up terminals using that script
install -Dpm0755 -t /usr/bin /usr/share/gnome-shell/extensions/logomenu@aryan_k/distroshelf-helper
install -Dpm0755 -t /usr/bin /usr/share/gnome-shell/extensions/logomenu@aryan_k/missioncenter-helper
glib-compile-schemas --strict /usr/share/gnome-shell/extensions/logomenu@aryan_k/schemas

# Search Light
glib-compile-schemas --strict /usr/share/gnome-shell/extensions/search-light@icedman.github.com/schemas

tee /usr/share/glib-2.0/schemas/zz3-bluefin-unsupported-stuff.gschema.override <<EOF
[org.gnome.shell]
disable-extension-version-validation='true'
EOF

# gnome extensions
HARDCODED_RPM_MONTH="12"
sed -i "/picture-uri/ s/${HARDCODED_RPM_MONTH}/$(date +%m)/" "/usr/share/glib-2.0/schemas/zz0-bluefin-modifications.gschema.override"

rm /usr/share/glib-2.0/schemas/gschemas.compiled
glib-compile-schemas /usr/share/glib-2.0/schemas

mkdir -p "/usr/share/fonts/Maple Mono"

JBMONO_TMPDIR="$(mktemp -d)"
trap 'rm -rf "${JBMONO_TMPDIR}"' EXIT

curl -fSsLo "${JBMONO_TMPDIR}/jbmono.zip" "https://github.com/JetBrains/JetBrainsMono/releases/download/v2.304/JetBrainsMono-2.304.zip"
unzip "${JBMONO_TMPDIR}/jbmono.zip" -d "/usr/share/fonts/JetBrains Mono"

echo "DEFAULT_HOSTNAME=bluefin" | tee -a /usr/lib/os-release

systemctl enable brew-setup.service
systemctl enable brew-upgrade.timer
systemctl enable brew-update.timer
