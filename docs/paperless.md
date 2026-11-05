# paperless

Document archive: Paperless-ngx, Postgres, Valkey, Gotenberg, Tika, and a WebDAV inbox that writes into the consume claim. AI uses the models [ollama](ollama.md) pulls.

## Flux

Flux applies `apps/paperless.yaml` in namespace `paperless`, from `charts/paperless`. TLS is the reflected certificate. The archive host is `publicURL` in `charts/paperless/values.yaml`, and the [session gate](oauth2-proxy.md) serves it on the LAN only. The WebDAV host is `webdav.host` in the same file and is also a Blocky mapping in `dns/blocky.yaml`. WebDAV is not behind the gate, and neither host is a tunnel route.

## Secrets

The Paperless SOPS secret holds the database password and the app secret. Keep it when restoring, because new values only fit an empty database. The Paperless gate SOPS secret holds the Pocket ID client secret and the gate cookie secret for this namespace only. The client secret has to be URL-safe, since a quote or a backslash breaks the provider JSON once Kubernetes substitutes it. The WebDAV SOPS secret holds the WebDAV username and password.

## Sign-in

Sign-in is [Pocket ID](pocket-id.md), and the username form is off.

## Rebuild

1. The reflected TLS secret is in this namespace.
2. Keep the existing app secret, or fill an empty install:

```sh
task sops:edit -- secrets/paperless.enc.yaml
```

3. Reconcile and wait until the claims are Bound.
4. Restore the data, media, and consume claims before signing in. The database claim is not in the backup. On an empty database, sign in first with a Pocket ID user in the `admins` group, because that account becomes the admin. Later users are normal users.
5. Wait until Ollama has pulled the models this chart names before using AI.
6. Set the WebDAV username and password:

```sh
task sops:edit -- secrets/paperless-webdav.enc.yaml
```

## Check

HelmRelease `paperless` is Ready, and its Ingress host answers. The WebDAV pod is Ready, and its Ingress host asks for the password.

## Restore

Restore the data, media, and consume claims. The database claim is not in the backup, and the broker is left out because the queue is rebuilt.

```sh
task backup:restore -- paperless
```

The claims must already be Bound. See [velero](velero.md).
