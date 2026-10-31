# cert-manager

Issues the wildcard certificate with Let's Encrypt DNS-01 against Cloudflare. No inbound port. Reflector copies the TLS secret into every namespace so Ingresses can mount it.

Flux applies `platform/cert-manager/`, `sources/cert-manager.yaml`, `certs/`, and `platform/reflector.yaml`. The API token is `secrets/cloudflare-dns-01-token.enc.yaml`.

## Rebuild

The token in git is reused when Secret `flux-system/sops-age` decrypts. Create a new token only when that one is gone:

1. In the Cloudflare dashboard, create an API token that can edit DNS on the zone the Certificate requests.
2. Put it in `secrets/cloudflare-dns-01-token.enc.yaml`, at the key `certs/clusterissuer.yaml` references.

```sh
task sops:edit -- secrets/cloudflare-dns-01-token.enc.yaml
```

3. Push and `task reconcile`.

## Check

HelmReleases `cert-manager` and `reflector` are Ready. The Certificate is Ready.

```sh
kubectl -n cert-manager get certificate
```
