# authentik

Signs in Paperless and Open WebUI. Accounts live in its Postgres claim. [volume-backup](volume-backup.md) copies that claim. Local username and password on both apps stay available.

Flux applies `apps/authentik.yaml` in namespace `authentik`. TLS is the reflected certificate. The host is the Ingress host in that file, and that name is also a Blocky mapping in `apps/blocky.yaml`. It is not a tunnel route. Client secrets are `secrets/authentik-sso.enc.yaml`, reflected into `paperless` and `ai`. The app secret and database password are the other two secrets in that namespace.

The bootstrap email and password are in `secrets/authentik.enc.yaml`. Change them before the database exists.

## Rebuild

1. The reflected TLS secret is in this namespace.
2. Set the bootstrap email and password:

```sh
task sops:edit -- secrets/authentik.enc.yaml
```

3. Reconcile and wait until the Postgres claim is Bound.
4. Restore that claim before signing in, when bringing a database back. On an empty database, the bootstrap account is the admin.
5. Open Paperless and Open WebUI and use the Authentik button. An existing Paperless user links it from **My profile**. An Open WebUI user with the same email is the same account.

## Check

HelmRelease `authentik` is Ready. Its Ingress host shows the login page. Paperless and Open WebUI show an Authentik button.

## Restore

Keep the three Authentik secrets. The restore replaces the database directory and restarts its writer.

```sh
task backup:restore -- authentik data-authentik-postgresql-0
```

The claim must already be Bound.
