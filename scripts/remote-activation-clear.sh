#!/bin/sh
# Executed on the remote host over SSH stdin. Never stop a running activation.
set -eu
unit=fleet-remote-activation.service
refuse() {
	printf '%s\n' "Refusing to clear $unit: $*" >&2
	exit 1
}
# Query failures must propagate, not be interpreted as an absent unit.
jobs=$(sudo systemctl list-jobs --no-legend --no-pager)
while read -r id name rest; do
	[ "$name" != "$unit" ] || refuse "pending systemd job"
done <<EOF
$jobs
EOF
units=$(sudo systemctl list-units --all --plain --no-legend --no-pager "$unit")
if [ -z "$units" ]; then
	printf '%s\n' "$unit is absent; nothing to clear."
	exit 0
fi
state=$(sudo systemctl show "$unit" --property=LoadState,ActiveState,SubState,Result,ExecMainCode,ExecMainStatus,Job)
load= active= sub= result= code= status= job=unknown
while IFS='=' read -r key value; do
	case "$key" in
		LoadState) load=$value ;;
		ActiveState) active=$value ;;
		SubState) sub=$value ;;
		Result) result=$value ;;
		ExecMainCode) code=$value ;;
		ExecMainStatus) status=$value ;;
		Job) job=$value ;;
		*) refuse "unexpected query output" ;;
	esac
done <<EOF
$state
EOF
case "$job" in ''|0) ;; *) refuse "pending or unknown job: $job" ;; esac
[ "$load" = loaded ] || refuse "unexpected load state: $load"
# There is no atomic systemctl compare-state-and-stop operation. Operators must
# not concurrently start/manage this unit: a job could arrive after this check.
# Retention prevents our normal launch path from replacing a completed unit.
case "$active/$sub" in
	active/exited)
		[ "$result/$code/$status" = success/1/0 ] || refuse "unsuccessful or unknown exit result"
		sudo systemctl stop "$unit"
		;;
	failed/failed)
		sudo systemctl reset-failed "$unit"
		;;
	*) refuse "unexpected state: $active/$sub" ;;
esac
printf '%s\n' "Cleared $unit."
