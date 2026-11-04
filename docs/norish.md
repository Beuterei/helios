# norish

Recipes, the meal plan, and the grocery list. Postgres holds the accounts. Uploads are recipe files. Valkey is the queue. Obscura renders pages for URL imports.

Flux applies `apps/norish.yaml` in namespace `norish`, from `charts/norish`. TLS is the reflected certificate. The host is `ingress.host` in that chart, and that name is also a Blocky mapping in `apps/blocky.yaml`. [oauth2-proxy](oauth2-proxy.md) publishes it.

Sign-in is [Pocket ID](pocket-id.md). The username form is off. `secrets/norish.enc.yaml` is the database password, the master key, and the Obscura token. Keep that secret when restoring. New values only fit an empty database. The master key decrypts data already stored.

Restore the database and the uploads claim. Skip Valkey; the queue is rebuilt.

## Rebuild

1. The reflected TLS secret is in this namespace.
2. Keep the existing secret, or fill an empty install before the first start:

```sh
task sops:edit -- secrets/norish.enc.yaml
```

3. Create the Pocket ID group and client. See [pocket-id](pocket-id.md). Copy the client secret into the SSO secret. Pocket ID shows it once.

```sh
task sops:edit -- secrets/pocket-id-sso.enc.yaml
```

4. Reconcile and wait until the claims are Bound.
5. Restore the database and uploads before signing in. On an empty database, sign in with a Pocket ID user in the `admins` group first. That account is the admin, and Norish turns registration off. Turn it back on under **Settings → Admin**, on the General card, **Allow new user registration**. Password sign-in stays off. A later Pocket ID user in `norish` or `admins` then gets an account. `admins` is a Norish admin. `norish` is a normal user.

## Check

HelmRelease `norish` is Ready. Its Ingress host shows the login page.

## Restore

```sh
task backup:restore -- norish norish-postgres
task backup:restore -- norish norish-uploads
```

Each claim must already be Bound. The restore replaces that directory and restarts its writers.
