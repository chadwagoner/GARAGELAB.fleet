#!/bin/sh
# Exercise the repository Makefile against disposable, real Nix fixtures.
set -eu

repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
make_command=$(command -v make)
command -v nix-instantiate >/dev/null
work=$(mktemp -d "${TMPDIR:-/tmp}/fleet-nix-parse.XXXXXX")
trap 'rm -rf "$work"' 0
trap 'exit 1' HUP INT TERM
mkdir -p "$work/fixtures/directory with spaces" "$work/fixtures/.git" "$work/bin"
printf '{ answer = 42; }\n' > "$work/fixtures/directory with spaces/valid file.nix"
printf '{ broken = ; }\n' > "$work/fixtures/.git/ignored.nix"

run_make() {
    (cd "$work/fixtures" && "$make_command" -f "$repo/Makefile" "$@") > "$work/output" 2>&1
}

assert_no_success() {
    if grep -q 'All Nix files parsed successfully' "$work/output"; then
        printf 'FAIL: parse failure printed a success message\n' >&2
        exit 1
    fi
}

run_make nix-parse
grep -q 'All Nix files parsed successfully' "$work/output"

printf '{ broken = ; }\n' > "$work/fixtures/invalid.nix"
if run_make nix-parse; then
    printf 'FAIL: invalid Nix was accepted\n' >&2
    exit 1
fi
assert_no_success

# A flake command must never run after a parse failure.
printf '#!/bin/sh\n: > "%s"\n' "$work/flake-called" > "$work/bin/nix"
chmod +x "$work/bin/nix"
if run_make nix-check "NIX=$work/bin/nix"; then
    printf 'FAIL: nix-check accepted invalid Nix\n' >&2
    exit 1
fi
assert_no_success
test ! -e "$work/flake-called"
rm "$work/fixtures/invalid.nix"

# Keep only the recipe's shell/find available: nix-instantiate is absent.
mkdir "$work/no-parser"
ln -s "$(command -v sh)" "$work/no-parser/sh"
ln -s "$(command -v find)" "$work/no-parser/find"
if (PATH="$work/no-parser"; export PATH; run_make nix-parse); then
    printf 'FAIL: missing nix-instantiate was accepted\n' >&2
    exit 1
fi
assert_no_success
printf 'nix-parse regression tests passed.\n'
