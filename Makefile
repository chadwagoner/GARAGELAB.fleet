SHELL := /bin/sh

.DEFAULT_GOAL := help

HOST ?= cobra
REMOTE ?= cobra
FLAKE ?= .
REMOTE_FLAKE ?= github:chadwagoner/GARAGELAB.fleet
NIX ?= nix
NIX_FLAGS ?= --extra-experimental-features "nix-command flakes"
AGENIX_FLAKE ?= github:ryantm/agenix
XDG_CACHE_HOME ?= /private/tmp/garagelab-fleet-nix-cache

export XDG_CACHE_HOME

.PHONY: help \
	git-cleanup-preview git-cleanup git-pr-create \
	nix-info nix-config-check nix-parse nix-show nix-eval nix-check nix-update agenix-edit \
	remote-build remote-dry-activate remote-test remote-switch remote-status

help: ## Show available targets.
	@awk 'BEGIN { FS = ":.*## " } /^[a-zA-Z0-9_.-]+:.*## / { printf "  %-22s %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

git-cleanup-preview: ## Fetch, prune, and list local branches whose upstream is gone.
	@git fetch --prune
	@git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads | \
		awk 'index($$0, "[gone]") { print $$1 }'

git-cleanup: ## Fetch, prune, and delete local branches whose upstream is gone.
	@git fetch --prune
	@git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads | \
		awk 'index($$0, "[gone]") { print $$1 }' | \
		while IFS= read -r branch; do \
			[ -n "$$branch" ] && git branch -D "$$branch"; \
		done

git-pr-create: ## Create a pull request against main using commit metadata.
	@gh pr create --base main --fill

nix-info: ## Show the local CPU, Nix version, and configured Nix system.
	@printf 'CPU:        %s\n' "$$(uname -m)"
	@printf 'Nix:        %s\n' "$$($(NIX) --version)"
	@printf 'Nix system: %s\n' "$$($(NIX) $(NIX_FLAGS) config show system)"

nix-config-check: ## Check the local Nix installation and daemon connectivity.
	@$(NIX) $(NIX_FLAGS) config check

nix-parse: ## Parse every Nix file without evaluating the NixOS configuration.
	@find . -type f -name '*.nix' -not -path './.git/*' \
		-exec nix-instantiate --parse {} \; >/dev/null
	@printf 'All Nix files parsed successfully.\n'

nix-show: ## Show the flake outputs without building them.
	@$(NIX) $(NIX_FLAGS) flake show --no-write-lock-file "$(FLAKE)"

nix-eval: ## Evaluate the selected host's NixOS system derivation.
	@$(NIX) $(NIX_FLAGS) eval --no-write-lock-file \
		"$(FLAKE)#nixosConfigurations.$(HOST).config.system.build.toplevel.drvPath" --raw
	@printf '\n'

nix-check: nix-parse ## Run flake checks without building Linux outputs.
	@$(NIX) $(NIX_FLAGS) flake check --no-build --no-write-lock-file "$(FLAKE)"

nix-update: ## Update flake inputs and flake.lock.
	@$(NIX) $(NIX_FLAGS) flake update --flake "$(FLAKE)"

agenix-edit: ## Edit an age secret (AGE_FILE=path/to/secret.age).
	@if [ -z "$(AGE_FILE)" ]; then \
		printf 'Usage: make agenix-edit AGE_FILE=path/to/secret.age\n' >&2; \
		exit 2; \
	fi
	@cd ./secrets && $(NIX) $(NIX_FLAGS) run "$(AGENIX_FLAKE)" -- -e "$(AGE_FILE)"

remote-build: ## Build the selected configuration on the NixOS host.
	@ssh "$(REMOTE)" sudo nixos-rebuild build \
		--flake "$(REMOTE_FLAKE)#$(HOST)" --refresh

remote-dry-activate: ## Show what activation would change on the NixOS host.
	@ssh "$(REMOTE)" sudo nixos-rebuild dry-activate \
		--flake "$(REMOTE_FLAKE)#$(HOST)" --refresh

remote-test: ## Build and temporarily activate the configuration on the NixOS host.
	@ssh "$(REMOTE)" sudo nixos-rebuild test \
		--flake "$(REMOTE_FLAKE)#$(HOST)" --refresh

remote-switch: ## Build and persistently activate the configuration on the NixOS host.
	@ssh "$(REMOTE)" sudo nixos-rebuild switch \
		--flake "$(REMOTE_FLAKE)#$(HOST)" --refresh

remote-status: ## Show failed systemd units and recent boot errors on the NixOS host.
	@ssh "$(REMOTE)" 'systemctl --failed; journalctl -b -p err..alert --no-pager -n 50'

remote-reboot: ## Reboot the NixOS host.
	@ssh "$(REMOTE)" sudo shutdown -r now
