.PHONY: help seal-cloudflare seal-vaultwarden seal-seafile

KUBECTL ?= kubectl
KUBESEAL ?= kubeseal
SEAL_CERT ?= /path/to/sealed-secrets-public.pem

help:
	@echo "Targets:"
	@echo "  seal-cloudflare   Generate SealedSecret for Cloudflare API token"
	@echo "  seal-vaultwarden  Generate SealedSecret for Vaultwarden admin token"
	@echo "  seal-seafile      Generate SealedSecret for Seafile DB/admin creds"

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
