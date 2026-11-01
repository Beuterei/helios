# paperless

Document archive: Paperless-ngx, Postgres, Valkey, Gotenberg, Tika, the RAG adapter, and a WebDAV inbox, from `charts/paperless`. WebDAV writes into the consume claim. Its host is `webdav.host` in `charts/paperless/values.yaml`, and that name is also a Blocky mapping in `apps/blocky.yaml`. It is not a tunnel route.

Flux applies `apps/paperless.yaml` in namespace `paperless`. TLS is the reflected certificate. AI uses the models [ollama](ollama.md) pulls.

`secrets/paperless.enc.yaml` is the database password and app secret. Keep that secret when restoring. New values only fit an empty database.

Open WebUI searches this archive through the RAG adapter. That adapter reads `secrets/paperless-api-token.enc.yaml`. Create the token in Paperless (user menu → My profile → API tokens) and replace the placeholder:

```sh
task sops:edit -- secrets/paperless-api-token.enc.yaml
```

Restore the database, data, and media claims. Restore the consume claim only if the inbox had files. Skip the broker; the queue is rebuilt.

## Rebuild

1. The reflected TLS secret is in this namespace.
2. Keep the existing app secret, or fill an empty install:

```sh
task sops:edit -- secrets/paperless.enc.yaml
```

3. Reconcile and wait until the claims are Bound.
4. Restore the database, data, and media before signing in. On an empty database, the first Authentik sign-in is the admin.
5. Wait until Ollama has pulled the models this chart names before using AI.
6. After the first admin exists, create an API token and put it in `secrets/paperless-api-token.enc.yaml`. Reconcile. The RAG adapter stays unusable until that token is real.
7. In [open-webui](open-webui.md), enable the Paperless tool.
8. Sign-in is [authentik](authentik.md). The username form is off.
9. Set the WebDAV username and password:

```sh
task sops:edit -- secrets/paperless-webdav.enc.yaml
```

## Check

HelmRelease `paperless` is Ready. Its Ingress host answers. After the API token is real, the RAG adapter pod is Ready. The WebDAV pod is Ready, and its Ingress host asks for the password.

## Restore

```sh
task backup:restore -- paperless paperless-postgres
task backup:restore -- paperless paperless-data
task backup:restore -- paperless paperless-media
```

Each claim must already be Bound. The restore replaces that directory and restarts its writers.
