#!/bin/bash
set -euo pipefail
shopt -s nullglob

DIR="$(dirname "$0")"
CNFDIR="/etc/bacula/local.d"
[[ -f /etc/bacula/local.d/extra.sh ]] && . /etc/bacula/local.d/extra.sh sd

set -o allexport
. /etc/sysconfig/bacula-vars
set +o allexport

. "${DIR}/../helpers.sh"

env_fill "$(flexible_check sd-director.conf)"

# Emit one Device per configured slot. Slots are created by the apnscp-bacula
# addin as subdirectories of local.d/servers; each slot's Archive Device path
# (${STORAGE_PATH}/<slot>) is created by the addin as well.
STORAGE_PATH="${STORAGE_PATH:-/home/bacula}"
if [ -d "${CNFDIR}/servers" ]; then
	find "${CNFDIR}/servers" -mindepth 1 -maxdepth 1 -type d | sort -V | while read -r n ; do
		SLOT=$(basename "$n")
		# Only numeric slot directories map to devices
		[[ "$SLOT" =~ ^[0-9]+$ ]] || continue
		cat <<EOF
Device {
  Name = FileStorage-${SLOT}
  Media Type = File
  Archive Device = ${STORAGE_PATH}/${SLOT}
  LabelMedia = yes
  Random Access = Yes
  AutomaticMount = yes
  RemovableMedia = no
  AlwaysOpen = yes
}
EOF
	done
fi
