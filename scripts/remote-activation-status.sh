#!/bin/sh
# Read-only remote inspection. A cleared activation does not erase boot state.
set -u
unit=fleet-remote-activation.service
rc=0
units=$(sudo systemctl list-units --all --plain --no-legend --no-pager "$unit")
query_rc=$?
if [ "$query_rc" -ne 0 ]; then
	printf '%s\n' 'Activation state: UNKNOWN (systemd query failed)' >&2
	rc=$query_rc
elif [ -z "$units" ]; then
	printf '%s\n' "Activation unit: absent (cleared or not run); no retained result."
else
	# Keep systemctl's status/result display and nonzero failure semantics.
	sudo systemctl status "$unit" --no-pager
	status_rc=$?
	[ "$status_rc" -eq 0 ] || rc=$status_rc
	printf '%s\n' 'Activation completion requires active (exited), Result=success, ExecMainCode=1 and ExecMainStatus=0; running is not complete.'
	sudo systemctl show "$unit" --property=ActiveState,SubState,Result,ExecMainCode,ExecMainStatus
	show_rc=$?
	[ "$show_rc" -eq 0 ] || rc=$show_rc
fi

unknown=0
changed=
canonical() {
	resolved=$(readlink -e "$1") || return 1
	# Only exact, existing canonical store paths are meaningful comparisons.
	case "$resolved" in /nix/store/*) ;; *) return 1 ;; esac
	store=${resolved#/nix/store/}
	hash=${store%%-*}
	[ "${#hash}" -eq 32 ] || return 1
	case "$hash" in *[!0123456789abcdfghijklmnpqrsvwxyz]*) return 1 ;; esac
	case "$store" in "$hash"-?*) ;; *) return 1 ;; esac
	case "$resolved" in *'
'*|*/../*|*/./*|*//*|*/) return 1 ;; esac
	printf '%s\n' "$resolved"
}
for component in kernel kernel-modules initrd; do
	booted=$(canonical "/run/booted-system/$component")
	b=$?
	installed=$(canonical "/nix/var/nix/profiles/system/$component")
	i=$?
	if [ "$b" -ne 0 ] || [ "$i" -ne 0 ]; then
		printf '%s\n' "$component: UNKNOWN (missing, unreadable or invalid canonical store path)"
		unknown=1
	else
		printf '%s\n' "$component booted:    $booted" "$component installed: $installed"
		if [ "$booted" != "$installed" ]; then
			changed="${changed}${changed:+, }$component"
		fi
	fi
done
if [ -n "$changed" ]; then
	printf '%s\n' "Changed boot components: $changed"
fi
if [ "$unknown" -ne 0 ]; then
	printf '%s\n' 'Reboot required: UNKNOWN (boot comparison incomplete)'
	[ "$rc" -ne 0 ] || rc=1
elif [ -n "$changed" ]; then
	printf '%s\n' 'Reboot required: YES'
else
	printf '%s\n' 'Reboot required: NO'
fi
if running=$(uname -r); then
	printf '%s\n' "Running kernel version: $running"
else
	printf '%s\n' 'Running kernel version: UNKNOWN (query failed)'
	[ "$rc" -ne 0 ] || rc=1
fi
# The modules directory is more reliable than parsing a store derivation name.
set -- /nix/var/nix/profiles/system/kernel-modules/lib/modules/*
if [ "$#" -eq 1 ] && [ -d "$1" ]; then
	printf '%s\n' "Installed kernel version: ${1##*/}"
else
	printf '%s\n' 'Installed kernel version: UNKNOWN'
fi
exit "$rc"
