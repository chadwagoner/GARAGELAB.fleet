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
BACKUP_REPOSITORY ?= /srv/backup/$(HOST)/restic
BACKUP_PASSWORD_FILE ?= /run/agenix/$(HOST)-container-backup-restic-password
BACKUP_USER ?= nix
SNAPSHOT ?= latest

export XDG_CACHE_HOME

.PHONY: help \
	git-cleanup-preview git-cleanup git-pr-create \
	nix-info nix-config-check nix-parse nix-show nix-eval nix-check nix-update agenix-edit \
	remote-build remote-dry-activate remote-test remote-switch remote-status \
	remote-container-services remote-containers \
	remote-backup-prepare remote-backup remote-backup-status remote-backup-list \
	remote-backup-files remote-backup-download remote-backup-check \
	remote-backup-check-data remote-backup-maintenance remote-reboot

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

remote-container-services: ## Show systemd status for all Podman container services.
	@ssh "$(REMOTE)" systemctl list-units 'podman-*.service' --all --no-pager

remote-containers: ## List all Podman containers, including stopped containers.
	@ssh "$(REMOTE)" 'sudo podman container ls --all --format "table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}"'

remote-backup-prepare: ## Ensure the remote host's hostname backup directory exists.
	@ssh "$(REMOTE)" sudo systemctl start fleet-container-volume-backup-prepare.service

remote-backup: ## Run the container-volume backup on the remote host now.
	@ssh "$(REMOTE)" sudo systemctl start fleet-container-volume-backup.service

remote-backup-status: ## Show container-volume backup timers and recent logs.
	@ssh "$(REMOTE)" 'systemctl list-timers "fleet-container-volume-backup*" --all --no-pager; sudo journalctl -u fleet-container-volume-backup.service -n 100 --no-pager'

remote-backup-list: ## List snapshots, optionally filtered with VOLUME=name.
	@if [ -n "$(VOLUME)" ]; then \
		case "$(VOLUME)" in *[!A-Za-z0-9_.-]*) printf 'Invalid VOLUME: %s\n' "$(VOLUME)" >&2; exit 2;; esac; \
		ssh "$(REMOTE)" sudo -u "$(BACKUP_USER)" restic \
			--repo "$(BACKUP_REPOSITORY)" \
			--password-file "$(BACKUP_PASSWORD_FILE)" \
			snapshots --tag "volume:$(VOLUME)"; \
	else \
		ssh "$(REMOTE)" sudo -u "$(BACKUP_USER)" restic \
			--repo "$(BACKUP_REPOSITORY)" \
			--password-file "$(BACKUP_PASSWORD_FILE)" \
			snapshots --tag container-volume; \
	fi

remote-backup-files: ## List files (VOLUME=name, optional SNAPSHOT=id; default latest).
	@if [ -z "$(SNAPSHOT)" ] || { [ "$(SNAPSHOT)" = latest ] && [ -z "$(VOLUME)" ]; }; then \
		printf 'Usage: make remote-backup-files VOLUME=name [SNAPSHOT=id]\n' >&2; \
		exit 2; \
	fi
	@case "$(SNAPSHOT)" in *[!A-Za-z0-9_.-]*) printf 'Invalid SNAPSHOT: %s\n' "$(SNAPSHOT)" >&2; exit 2;; esac
	@if [ -n "$(VOLUME)" ]; then \
		case "$(VOLUME)" in *[!A-Za-z0-9_.-]*) printf 'Invalid VOLUME: %s\n' "$(VOLUME)" >&2; exit 2;; esac; \
		ssh "$(REMOTE)" sudo -u "$(BACKUP_USER)" restic \
			--repo "$(BACKUP_REPOSITORY)" \
			--password-file "$(BACKUP_PASSWORD_FILE)" \
			ls --tag "volume:$(VOLUME)" "$(SNAPSHOT)"; \
	else \
		ssh "$(REMOTE)" sudo -u "$(BACKUP_USER)" restic \
			--repo "$(BACKUP_REPOSITORY)" \
			--password-file "$(BACKUP_PASSWORD_FILE)" \
			ls "$(SNAPSHOT)"; \
	fi

remote-backup-download: ## Download archive (VOLUME=name OUTPUT=file.tar; optional SNAPSHOT=id).
	@if [ -z "$(SNAPSHOT)" ] || [ -z "$(VOLUME)" ] || [ -z "$(OUTPUT)" ]; then \
		printf 'Usage: make remote-backup-download VOLUME=name OUTPUT=file.tar [SNAPSHOT=id]\n' >&2; \
		exit 2; \
	fi
	@case "$(SNAPSHOT)" in *[!A-Za-z0-9_.-]*) printf 'Invalid SNAPSHOT: %s\n' "$(SNAPSHOT)" >&2; exit 2;; esac
	@case "$(VOLUME)" in *[!A-Za-z0-9_.-]*) printf 'Invalid VOLUME: %s\n' "$(VOLUME)" >&2; exit 2;; esac
	@set -eu; \
		if [ -e "$(OUTPUT)" ] || [ -e "$(OUTPUT).partial" ]; then \
			printf 'Refusing to overwrite existing output or partial file: %s\n' "$(OUTPUT)" >&2; \
			exit 2; \
		fi; \
		trap 'rm -f "$(OUTPUT).partial"' EXIT HUP INT TERM; \
		ssh "$(REMOTE)" sudo -u "$(BACKUP_USER)" restic \
			--repo "$(BACKUP_REPOSITORY)" \
			--password-file "$(BACKUP_PASSWORD_FILE)" \
			dump --tag "volume:$(VOLUME)" "$(SNAPSHOT)" "$(VOLUME).tar" > "$(OUTPUT).partial"; \
		mv "$(OUTPUT).partial" "$(OUTPUT)"; \
		trap - EXIT HUP INT TERM; \
		printf 'Downloaded %s\n' "$(OUTPUT)"

remote-backup-check: ## Check Restic repository integrity without reading all data.
	@ssh "$(REMOTE)" sudo -u "$(BACKUP_USER)" restic \
		--repo "$(BACKUP_REPOSITORY)" \
		--password-file "$(BACKUP_PASSWORD_FILE)" \
		check

remote-backup-check-data: ## Check repository integrity and read all stored data.
	@ssh "$(REMOTE)" sudo -u "$(BACKUP_USER)" restic \
		--repo "$(BACKUP_REPOSITORY)" \
		--password-file "$(BACKUP_PASSWORD_FILE)" \
		check --read-data

remote-backup-maintenance: ## Apply retention, prune old data, and check the repository.
	@ssh "$(REMOTE)" sudo systemctl start fleet-container-volume-backup-maintenance.service

remote-reboot: ## Reboot the NixOS host.
	@ssh "$(REMOTE)" sudo shutdown -r now
