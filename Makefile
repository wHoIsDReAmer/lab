.PHONY: help install-kubeseal fetch-seal-cert seal-cloudflare seal-vaultwarden seal-seafile

KUBECTL ?= kubectl
KUBESEAL ?= kubeseal
KUBESEAL_OS ?= linux
KUBESEAL_ARCH ?= amd64
KUBESEAL_BIN ?= ./bin/kubeseal
KUBESEAL_VERSION ?=
KUBESEAL_TAG ?=
SEAL_CERT ?= ./secrets/sealed-secrets-public.pem

help:
	@echo "Targets:"
	@echo "  install-kubeseal  Download kubeseal CLI into ./bin"
	@echo "  fetch-seal-cert   Fetch Sealed Secrets public cert into SEAL_CERT"
	@echo "  seal-cloudflare   Generate SealedSecret for Cloudflare API token"
	@echo "  seal-vaultwarden  Generate SealedSecret for Vaultwarden admin token"
	@echo "  seal-seafile      Generate SealedSecret for Seafile DB/admin creds"

install-kubeseal:
	@mkdir -p ./bin
	@TAG="$(KUBESEAL_TAG)"; \
	if [ -z "$$TAG" ] && [ -n "$(KUBESEAL_VERSION)" ]; then TAG="v$(KUBESEAL_VERSION)"; fi; \
	if [ -z "$$TAG" ]; then \
		TAG=$$(curl -fsSL https://api.github.com/repos/bitnami-labs/sealed-secrets/releases/latest | awk -F '"' '/"tag_name":/ {print $$4}'); \
	fi; \
	if [ -z "$$TAG" ]; then echo "Failed to determine kubeseal release tag" >&2; exit 1; fi; \
	VERSION=$${TAG#v}; \
	URL="https://github.com/bitnami-labs/sealed-secrets/releases/download/$${TAG}/kubeseal-$${VERSION}-$(KUBESEAL_OS)-$(KUBESEAL_ARCH).tar.gz"; \
	TMP="/tmp/kubeseal-$${VERSION}.tar.gz"; \
	curl -fsSL "$$URL" -o "$$TMP"; \
	tar -xz -C ./bin -f "$$TMP" kubeseal; \
	chmod +x "$(KUBESEAL_BIN)"; \
	echo "kubeseal installed at $(KUBESEAL_BIN)"

fetch-seal-cert:
	$(KUBESEAL) --fetch-cert > "$(SEAL_CERT)"

seal-cloudflare:
	@test -n "$(CLOUDFLARE_API_TOKEN)" || (echo "CLOUDFLARE_API_TOKEN is required" >&2; exit 1)
	$(KUBECTL) -n cert-manager create secret generic cloudflare-api-token-secret \
		--from-literal=api-token="$(CLOUDFLARE_API_TOKEN)" \
		--dry-run=client -o yaml | \
	$(KUBESEAL) --cert "$(SEAL_CERT)" --format yaml > \
		clusters/k3s/infra/cert-manager/sealedsecret-cloudflare.yml

seal-vaultwarden:
	@test -n "$(VAULTWARDEN_ADMIN_TOKEN)" || (echo "VAULTWARDEN_ADMIN_TOKEN is required" >&2; exit 1)
	$(KUBECTL) -n vaultwarden create secret generic vaultwarden-secret \
		--from-literal=ADMIN_TOKEN="$(VAULTWARDEN_ADMIN_TOKEN)" \
		--dry-run=client -o yaml | \
	$(KUBESEAL) --cert "$(SEAL_CERT)" --format yaml > \
		clusters/k3s/apps/vaultwarden/sealedsecret.yml

seal-seafile:
	@test -n "$(SEAFILE_DB_ROOT_PASSWD)" || (echo "SEAFILE_DB_ROOT_PASSWD is required" >&2; exit 1)
	@test -n "$(SEAFILE_ADMIN_EMAIL)" || (echo "SEAFILE_ADMIN_EMAIL is required" >&2; exit 1)
	@test -n "$(SEAFILE_ADMIN_PASSWORD)" || (echo "SEAFILE_ADMIN_PASSWORD is required" >&2; exit 1)
	$(KUBECTL) -n seafile create secret generic seafile-secret \
		--from-literal=DB_ROOT_PASSWD="$(SEAFILE_DB_ROOT_PASSWD)" \
		--from-literal=ADMIN_EMAIL="$(SEAFILE_ADMIN_EMAIL)" \
		--from-literal=ADMIN_PASSWORD="$(SEAFILE_ADMIN_PASSWORD)" \
		--dry-run=client -o yaml | \
	$(KUBESEAL) --cert "$(SEAL_CERT)" --format yaml > \
		clusters/k3s/apps/seafile/sealedsecret.yml
