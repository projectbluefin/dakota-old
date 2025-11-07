#!/usr/bin/bash

set -eoux pipefail

###############################################################################
# Main Build Script
###############################################################################
# This script follows the @ublue-os/bluefin pattern for build scripts.
# It uses set -eoux pipefail for strict error handling and debugging.
###############################################################################

# Source helper functions
# shellcheck source=/dev/null

echo "::group:: Copy GNOME Extensions and Schemas"

# Copy GNOME extensions from context
echo "Copying GNOME Shell extensions..."
rsync -rvK /ctx/usr/share/gnome-shell/extensions/ /usr/share/gnome-shell/extensions/

# Copy gsettings schemas override
echo "Copying gsettings schemas override..."
rsync -rvK /ctx/usr/share/glib-2.0/schemas/ /usr/share/glib-2.0/schemas/

echo "::endgroup::"
