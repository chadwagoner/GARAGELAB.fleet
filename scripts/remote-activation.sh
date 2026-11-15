#!/bin/sh
# SSH joins command arguments into shell text, so quote each remote argument too.
set -eu
action=$1
remote=$2
flake=$3
shift 3
case "$action" in
	clear)
		exec ssh "$@" "$remote" 'sh -s' < "$(dirname "$0")/remote-activation-clear.sh"
		;;
	test|switch) ;;
	*) exit 2 ;;
esac
quote() {
	printf "'"
	printf '%s' "$1" | sed "s/'/'\\\\''/g"
	printf "'"
}
# System services do not inherit the SSH/login environment. nixos-rebuild-ng
# invokes utilities such as test by name, so supply the NixOS system PATH.
# HOME also gives root's Nix configuration/cache a predictable location.
command="sudo systemd-run --system --no-block --unit=fleet-remote-activation.service --property=Type=exec --property=RemainAfterExit=yes --property=StandardOutput=journal --property=StandardError=journal --setenv=PATH=/run/wrappers/bin:/run/current-system/sw/bin:/nix/var/nix/profiles/default/bin --setenv=HOME=/root -- /run/current-system/sw/bin/nixos-rebuild $action --flake $(quote "$flake") --refresh"
printf '%s\n' \
	'Activation unit: fleet-remote-activation.service (retained to prevent overlapping activations).' \
	'After reconnecting, use make remote-activation-status and make remote-activation-logs with the same REMOTE.' \
	'Queued does NOT mean deployed: verify active (exited), successful exit status, and the journal.' \
	'Before another activation, inspect the result, then use make remote-activation-clear with the same HOST/REMOTE.' \
	'Clear refuses running or queued work; do not concurrently launch or manage this unit while clearing.'
if ssh "$@" "$remote" "$command"; then
	printf '%s\n' 'Launch request accepted; deployment result is not yet known.'
else
	result=$?
	printf '%s\n' 'Launch not confirmed. Inspect the unit after reconnecting before retrying (it may already be running).' >&2
	exit "$result"
fi
