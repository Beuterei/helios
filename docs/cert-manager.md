# cert-manager

Issues the wildcard certificate with Let's Encrypt DNS-01 against Cloudflare, so no inbound port is needed. Reflector copies the TLS secret into each namespace that serves its own Ingress.

## Flux

Flux applies `platform/cert-manager/`, `sources/cert-manager.yaml`, `certs/`, and `platform/reflector.yaml`.

## Secrets

The Cloudflare DNS-01 SOPS secret holds the API token, under the key `certs/clusterissuer.yaml` references.

## Rebuild

The token in git is reused when Secret `flux-system/sops-age` decrypts it. Create a new token only when that one is gone:

1. In the Cloudflare dashboard, go to My Profile → API Tokens → Create Token. Use a custom token, not the Global API Key.

   Permissions:

   - Zone → Zone → Read
   - Zone → DNS → Edit

   Zone Resources: Include → Specific zone → the zone in `certs/certificate.yaml`.

2. Put the token in the secret, at the key `certs/clusterissuer.yaml` references.

```sh
task sops:edit -- secrets/cloudflare-dns-01-token.enc.yaml
```

3. Push and `task reconcile`.

## Check

HelmReleases `cert-manager` and `reflector` are Ready, and the Certificate is Ready.

```sh
kubectl -n cert-manager get certificate
```
