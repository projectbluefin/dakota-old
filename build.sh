#!/usr/bin/env bash

set -xeuo pipefail

# Copy files from context
cp -avf "/tmp/ctx/files"/. /


# Caffeine extension setup
# The Caffeine extension is built/packaged into a temporary subdirectory.
# It must be moved to the standard extensions directory for GNOME Shell to detect it.
if [ -d /usr/share/gnome-shell/extensions/tmp/caffeine/caffeine@patapon.info ]; then
    mv /usr/share/gnome-shell/extensions/tmp/caffeine/caffeine@patapon.info /usr/share/gnome-shell/extensions/caffeine@patapon.info
fi

# Logo Menu setup
# xdg-terminal-exec is required for this extension
install -Dpm0755 -t /usr/bin /usr/share/gnome-shell/extensions/logomenu@aryan_k/distroshelf-helper
install -Dpm0755 -t /usr/bin /usr/share/gnome-shell/extensions/logomenu@aryan_k/missioncenter-helper

# GSchema compilation for extensions
for schema_dir in /usr/share/gnome-shell/extensions/*/schemas; do
    if [ -d "${schema_dir}" ]; then
        glib-compile-schemas --strict "${schema_dir}"
    fi
done

# Bluefin GSchema overrides
tee /usr/share/glib-2.0/schemas/zz3-bluefin-unsupported-stuff.gschema.override <<EOF
[org.gnome.shell]
disable-extension-version-validation=true
EOF

# Update background XML month dynamically
# Target both picture-uri and picture-uri-dark
HARDCODED_MONTH="12"
CURRENT_MONTH=$(date +%m)
sed -i "/picture-uri/ s/${HARDCODED_MONTH}/${CURRENT_MONTH}/g" "/usr/share/glib-2.0/schemas/zz0-bluefin-modifications.gschema.override"

# Compile system-wide schemas
rm -f /usr/share/glib-2.0/schemas/gschemas.compiled
glib-compile-schemas /usr/share/glib-2.0/schemas

/tmp/ctx/build_scripts/base/branding.sh

systemctl enable brew-setup.service

