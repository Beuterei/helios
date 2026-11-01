# paperless

Document archive: Paperless-ngx, Postgres, Valkey, Gotenberg, Tika, and a WebDAV inbox, from `charts/paperless`. WebDAV writes into the consume claim. Its host is `webdav.host` in `charts/paperless/values.yaml`, and that name is also a Blocky mapping in `apps/blocky.yaml`. It is not a tunnel route.

Flux applies `apps/paperless.yaml` in namespace `paperless`. TLS is the reflected certificate. AI uses the models [ollama](ollama.md) pulls.

`secrets/paperless.enc.yaml` is the database password and app secret. Keep that secret when restoring. New values only fit an empty database.

Restore the database, data, and media claims. Restore the consume claim only if the inbox had files. Skip the broker; the queue is rebuilt.

## Rebuild

1. The reflected TLS secret is in this namespace.
2. Keep the existing app secret, or fill an empty install:

```sh
task sops:edit -- secrets/paperless.enc.yaml
```

3. Reconcile and wait until the claims are Bound.
4. Restore the database, data, and media before signing in. On an empty database, sign in as `akadmin` first. That account is the admin. Other Authentik users are normal users.
5. Wait until Ollama has pulled the models this chart names before using AI.
6. Sign-in is [authentik](authentik.md). The username form is off.
7. Set the WebDAV username and password:

```sh
task sops:edit -- secrets/paperless-webdav.enc.yaml
```

## Check

HelmRelease `paperless` is Ready. Its Ingress host answers. The WebDAV pod is Ready, and its Ingress host asks for the password.

## Restore

```sh
task backup:restore -- paperless paperless-postgres
task backup:restore -- paperless paperless-data
task backup:restore -- paperless paperless-media
```

Each claim must already be Bound. The restore replaces that directory and restarts its writers.
