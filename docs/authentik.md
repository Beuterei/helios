# authentik

Signs in Paperless and Open WebUI. Accounts live in its Postgres claim. [volume-backup](volume-backup.md) copies that claim. Both apps sign in here. Their username forms are off.

Flux applies `apps/authentik.yaml` in namespace `authentik`. TLS is the reflected certificate. The host is the Ingress host in that file, and that name is also a Blocky mapping in `apps/blocky.yaml`. It is not a tunnel route. Client secrets are `secrets/authentik-sso.enc.yaml`, reflected into `paperless` and `ai`. The app secret and database password are the other two secrets in that namespace.

The bootstrap email and password are in `secrets/authentik.enc.yaml`. Change them before the database exists. The system base URL is `https://auth.luisbeu.de`.

A user can open an app only as a member of its group: **Paperless users** or **Open WebUI users**. Add the user to a group under **Directory → Groups**. Those groups are normal users of the app. **authentik Admins** can open both apps and is the admin in each. `akadmin` is always in that group.

## Rebuild

1. The reflected TLS secret is in this namespace.
2. Set the bootstrap email and password:

```sh
task sops:edit -- secrets/authentik.enc.yaml
```

3. Reconcile and wait until the Postgres claim is Bound.
4. Restore that claim before signing in, when bringing a database back. On an empty database, the bootstrap account is the admin.
5. Open Paperless and Open WebUI. Sign-in goes to Authentik. An Open WebUI account with the same email is the same account.

## Check

HelmRelease `authentik` is Ready. Its Ingress host shows the login page. Paperless and Open WebUI send sign-in there.

## Restore

Keep the three Authentik secrets. The restore replaces the database directory and restarts its writer.

```sh
task backup:restore -- authentik data-authentik-postgresql-0
```

The claim must already be Bound.
