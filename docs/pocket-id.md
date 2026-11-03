# pocket-id

Signs in Paperless, Open WebUI, and Norish. Accounts live on its claim. [volume-backup](volume-backup.md) copies that claim. Those apps sign in here. Their username forms are off. Sign-in is a passkey.

Flux applies `apps/pocket-id.yaml` in namespace `pocket-id`. TLS is the reflected certificate. The host is the Ingress host in that file, and that name is also a Blocky mapping in `apps/blocky.yaml`. It is not a tunnel route. Client secrets are `secrets/pocket-id-sso.enc.yaml`, reflected into `paperless`, `ai`, and `norish`. The encryption key is `secrets/pocket-id.enc.yaml`.

Change the encryption key before the database exists. The public address is `https://auth.luisbeu.de`, set with `APP_URL`.

A user can open an app only as a member of a group allowed on that client. The group **name** is the value in the token. The friendly name is only the label. **paperless**, **open_webui**, and **norish** are normal users of that app. **admins** can open each app and is the admin in each. Add a user under **Administration → Users**, and the groups under **Administration → User Groups**.

## Rebuild

1. The reflected TLS secret is in this namespace.
2. Set the encryption key before the first start:

```sh
task sops:edit -- secrets/pocket-id.enc.yaml
```

3. Reconcile and wait until the claim is Bound.
4. Restore that claim before signing in, when bringing a database back. On an empty database, open the Ingress host and create the admin passkey.
5. Create four groups. Leave the name the form fills in: `admins`, `paperless`, `open_webui`, and `norish`. Put the admin in all four.
6. Create a confidential client for each app. Choose **Set custom client ID** and use `paperless`, `open-webui`, and `norish`. Turn PKCE on. Callback URLs:

- Paperless: `https://paperless.luisbeu.de/accounts/oidc/pocket-id/login/callback/`
- Open WebUI: `https://chat.luisbeu.de/oauth/oidc/callback`
- Norish: `https://recipe.luisbeu.de/api/auth/callback/oidc`

On the Paperless client, allow `paperless` and `admins`. On the Open WebUI client, allow `open_webui` and `admins`. On the Norish client, allow `norish` and `admins`.

7. Copy each client secret into the SSO secret. Pocket ID shows the secret once.

```sh
task sops:edit -- secrets/pocket-id-sso.enc.yaml
```

8. Reconcile again so Paperless, Open WebUI, and Norish read those secrets.

## Check

HelmRelease `pocket-id` is Ready. Its Ingress host shows the login page. Paperless, Open WebUI, and Norish send sign-in there.

## Restore

Keep both Pocket ID secrets. The restore replaces the database directory and restarts its writer.

```sh
task backup:restore -- pocket-id pocket-id
```

The claim must already be Bound.
