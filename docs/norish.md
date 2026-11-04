# norish

Recipes, the meal plan, and the grocery list. Uploads are recipe files, Valkey is the queue, and Obscura renders pages for URL imports.

## Flux

Flux applies `apps/norish.yaml` in namespace `norish`, from `charts/norish`. TLS is the reflected certificate. The host is `publicURL` in that chart and is also a Blocky mapping in `dns/blocky.yaml`. [oauth2-proxy](oauth2-proxy.md) publishes it and skips auth on `GET /api/v1/health/ready`. Norish calls Pocket ID through Traefik, so its egress allows those pods as well as public HTTP.

## Secrets

The Norish SOPS secret holds the database password, the master key, and the Obscura token. Keep it when restoring, because new values only fit an empty database and the master key decrypts data already stored. The Norish gate SOPS secret holds the Pocket ID client secret and the gate cookie secret for this namespace only.

## Sign-in

Sign-in is [Pocket ID](pocket-id.md), and the username form and password sign-in are off. A Pocket ID user in `admins` is a Norish admin, and a user in `norish` is a normal user.

## Rebuild

1. The reflected TLS secret is in this namespace.
2. Keep the existing secret, or fill an empty install before the first start:

```sh
task sops:edit -- secrets/norish.enc.yaml
```

3. Create the Pocket ID group and client. See [pocket-id](pocket-id.md). Copy the client secret into the gate secret, because Pocket ID shows it only once.

```sh
task sops:edit -- secrets/norish-gate.enc.yaml
```

4. Reconcile and wait until the claims are Bound.
5. Restore the database and uploads before signing in. On an empty database, sign in first with a Pocket ID user in the `admins` group. That account becomes the admin, and Norish turns registration off. Turn it back on under **Settings → Admin**, on the General card, with **Allow new user registration**, so later Pocket ID users in `norish` or `admins` get an account.

## Check

HelmRelease `norish` is Ready, and its Ingress host shows the login page.

## Restore

Restore the database and the uploads claim. Valkey is skipped because the queue is rebuilt, so `norish-valkey` is not in the snapshot.

```sh
task backup:restore -- norish
```

The claims must already be Bound. One snapshot covers the namespace, and the restore replaces the directories and restarts their writers.
