# pocket-id

Identity provider for Paperless, Open WebUI, and Norish. Their username forms are off, and sign-in is a passkey. Accounts are in Postgres, which [velero](velero.md) leaves out. The claim holds uploads, which Velero copies.

## Flux

Flux applies `apps/pocket-id.yaml` in namespace `pocket-id`. TLS is the reflected certificate. The host is `publicURL` in `charts/pocket-id/values.yaml`, the chart sets `APP_URL` from it, and the same name is a Blocky mapping in `dns/blocky.yaml`. The tunnel origin is the headless service described in [cloudflared](cloudflared.md).

## Secrets

The Pocket ID SOPS secret holds the encryption key. The database password is in the secret named by `postgres.secretName`. The encryption key has to be set before the database exists, and the password only fits this database. Each app keeps its own client secret in its gate Secret.

## Sign-in

A user can open an app only as a member of a group allowed on that client. The token carries the group **name**, while the friendly name is only a label. **paperless**, **open_webui**, and **norish** are normal users of that app, and **admins** can open each app as its admin. Users are added under **Administration → Users** and groups under **Administration → User Groups**.

## Rebuild

1. The reflected TLS secret is in this namespace.
2. Set the encryption key before the first start:

```sh
task sops:edit -- secrets/pocket-id.enc.yaml
```

3. Reconcile and wait until the claims are Bound.
4. On an empty database, open the Ingress host and create the admin passkey. The database is a CloudNativePG cluster. To bring it back, follow [cloudnative-pg](cloudnative-pg.md).
5. Create the groups `admins`, `paperless`, `open_webui`, and `norish`, keeping the name the form fills in. Put the admin in all of them.
6. Create a confidential client for each app. Choose **Set custom client ID** and use `paperless`, `open-webui`, and `norish`. Turn PKCE on. Each host is the app's gate `host` in `apps/oauth2-proxy-<app>.yaml`. Callback URLs:

- Paperless: `https://<host>/accounts/oidc/pocket-id/login/callback/`
- Open WebUI: `https://<host>/oauth/oidc/callback`
- Norish: `https://<host>/api/auth/callback/oidc`

Add the session-gate callback `https://<host>/oauth2/callback` on the same client.

On the Paperless client, allow `paperless` and `admins`. On the Open WebUI client, allow `open_webui` and `admins`. On the Norish client, allow `norish` and `admins`.

7. Copy each client secret into that app's gate secret. Pocket ID shows the secret only once.

```sh
task sops:edit -- secrets/paperless-gate.enc.yaml
task sops:edit -- secrets/open-webui-gate.enc.yaml
task sops:edit -- secrets/norish-gate.enc.yaml
```

8. Reconcile again so Paperless, Open WebUI, and Norish read those secrets.

## Check

HelmRelease `pocket-id` is Ready, and its Ingress host shows the login page. Paperless, Open WebUI, and Norish send sign-in there.

## Restore

Keep the Pocket ID SOPS secret. The restore rewrites the uploads on the claim. The database is CloudNativePG. See [cloudnative-pg](cloudnative-pg.md).

```sh
task backup:restore -- pocket-id
```

The claim must already be Bound. See [velero](velero.md).
