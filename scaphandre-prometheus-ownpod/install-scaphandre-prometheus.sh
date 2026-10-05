#!/bin/bash
set -euo pipefail
# Use the same prebuilt installer as the Jupyter VRE Workflow button.
installer=/srv/telemetry-installer/install.sh
if [ ! -f "$installer" ]; then
  installer="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)/telemetry-installer/install.sh"
fi
if [ ! -f "$installer" ]; then
  echo 'Install the telemetry-installer ConfigMap or run this script from a checkout of L1EcoVRE.' >&2
  exit 1
fi
exec bash "$installer"
