#!/bin/bash
set -euo pipefail
shopt -s nullglob

DIR=$(dirname "$0")
CNFDIR="/etc/bacula/local.d/servers"
[[ -f /etc/bacula/local.d/extra.sh ]] && . /etc/bacula/local.d/extra.sh dir

set -o allexport
. /etc/sysconfig/bacula-vars
# Native driver name; fall back to mysql when DB_DRIVER is unset
DB_DRIVER="${DB_DRIVER:-mysql}"
set +o allexport

. "$(dirname "$0")/../helpers.sh"

env_fill "$(flexible_check director.conf)"

EXTRA="${EXTRA:-}"
TEMPLATE=$(grep -v '^[[:space:]]*#' "$(flexible_check servers/base.conf)")

env_fill "${DIR}/database.conf"

if [ -d "$CNFDIR" ]; then
	find "$CNFDIR" -mindepth 1 -maxdepth 1 -type d | while read -r n ; do
		SLOT=$(basename "$n")
		perl -n -pe 's!%N%!'"$SLOT"'!g;' "$(flexible_check servers/slot-base.conf)" "$(flexible_check servers/storage.conf)" | env_fill -
		for f in "$n"/*.conf ; do
				awk -v N="$SLOT" -v EXTRA="$EXTRA" -v TEMPLATE="$TEMPLATE" \
						'BEGIN {
								PASSWORD=""; DOMAIN=""; ADDRESS=""; FILESET="Client-Layer" ; gsub(/%N%/,N,TEMPLATE);
						}
						{
								if ($0 ~ /^[[:space:]]*#/) { exit; }
								else if ($0 ~ /Password/) { gsub(/%PASSWORD%/,$3,TEMPLATE); }
								else if ($0 ~ /Name/) { gsub(/%NAME%/,$3,TEMPLATE); }
								else if ($0 ~ /Address/) { gsub(/%ADDRESS%/, $3, TEMPLATE); }
								else if ($0 ~ /FileSet/) { gsub(/%FILESET%/, $3, TEMPLATE); }
						} ;
						END {
								gsub(/%FILESET%/, FILESET, TEMPLATE);
								if (EXTRA) {
										INDEX=index(TEMPLATE,"Job");
										if (INDEX > 0) {
												INDEX2=index(substr(TEMPLATE, INDEX),"}")-2;
												TEMPLATE=(substr(TEMPLATE, 1, INDEX+INDEX2) EXTRA substr(TEMPLATE, INDEX+INDEX2));
										}
								} ;
								print TEMPLATE
						}'  < "$f"
	done
done
fi