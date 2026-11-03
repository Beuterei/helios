# pocket-id

Signs in Paperless and Open WebUI. Accounts live on its claim. [volume-backup](volume-backup.md) copies that claim. Both apps sign in here. Their username forms are off. Sign-in is a passkey.

Flux applies `apps/pocket-id.yaml` in namespace `pocket-id`. TLS is the reflected certificate. The host is the Ingress host in that file, and that name is also a Blocky mapping in `apps/blocky.yaml`. It is not a tunnel route. Client secrets are `secrets/pocket-id-sso.enc.yaml`, reflected into `paperless` and `ai`. The encryption key is `secrets/pocket-id.enc.yaml`.

Change the encryption key before the database exists. The public address is `https://auth.luisbeu.de`, set with `APP_URL`.

A user can open an app only as a member of a group allowed on that client. The group **name** is the value in the token. The friendly name is only the label. **paperless** and **open_webui** are normal users of that app. **admins** can open both apps and is the admin in each. Add a user under **Administration → Users**, and the groups under **Administration → User Groups**.

## Rebuild

1. The reflected TLS secret is in this namespace.
2. Set the encryption key before the first start:

```sh
task sops:edit -- secrets/pocket-id.enc.yaml
```

3. Reconcile and wait until the claim is Bound.
4. Restore that claim before signing in, when bringing a database back. On an empty database, open the Ingress host and create the admin passkey.
5. Create three groups. Leave the name the form fills in: `admins`, `paperless`, and `open_webui`. Put the admin in all three.
6. Create a confidential client for each app. Choose **Set custom client ID** and use `paperless` and `open-webui`. Turn PKCE on. Callback URLs:

- Paperless: `https://paperless.luisbeu.de/accounts/oidc/pocket-id/login/callback/`
- Open WebUI: `https://chat.luisbeu.de/oauth/oidc/callback`

On the Paperless client, allow `paperless` and `admins`. On the Open WebUI client, allow `open_webui` and `admins`.

7. Copy each client secret into the SSO secret. Pocket ID shows the secret once.

```sh
task sops:edit -- secrets/pocket-id-sso.enc.yaml
```

8. Reconcile again so Paperless and Open WebUI read those secrets.
9. Delete namespace `authentik` once both apps sign in here. Flux no longer applies it.

## Check

HelmRelease `pocket-id` is Ready. Its Ingress host shows the login page. Paperless and Open WebUI send sign-in there.

## Restore

Keep both Pocket ID secrets. The restore replaces the database directory and restarts its writer.

```sh
task backup:restore -- pocket-id pocket-id
```

The claim must already be Bound.
