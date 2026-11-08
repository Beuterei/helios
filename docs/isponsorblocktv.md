# isponsorblocktv

Skips SponsorBlock segments on YouTube TV clients on the LAN. There is no web UI. The ConfigMap holds `config.json`, and an init container copies it into `/app/data` with the screen id from the Secret.

## Flux

Flux applies `apps/isponsorblocktv.yaml` in namespace `isponsorblocktv`, from `charts/isponsorblocktv`.

## Secrets

The SOPS secret holds the YouTube TV `screen-id`. Pair the TV once with the upstream setup tool, then put that id in the secret:

```sh
task sops:edit -- secrets/isponsorblocktv.enc.yaml
```

## Rebuild

1. Fill the secret before the first reconcile.
2. Reconcile.

## Check

HelmRelease `isponsorblocktv` is Ready, and the pod log shows the TV connected.

```sh
kubectl -n isponsorblocktv logs deploy/isponsorblocktv -c isponsorblocktv --tail=50
```

## Restore

No claim. Keep the screen id secret.
