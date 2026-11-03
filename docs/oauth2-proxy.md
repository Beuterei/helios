# oauth2-proxy

Session gate for Norish, Paperless, and Open WebUI. A request needs a Pocket ID session before the app container is contacted. Norish is also on the tunnel. Paperless and Open WebUI are LAN only. Pocket ID stays open, or the login cannot finish. Paperless WebDAV stays on its own password.

Flux applies three HelmReleases of `charts/oauth2-proxy`, one in each app namespace. Each app accepts its HTTP port only from its gate. Traefik can open every gate. cloudflared can open the Norish gate only.

An existing Pocket ID session is reused. The first visit still sets the gate cookie and the app cookie. Later visits use those cookies until one of them expires.

Cookie secrets are `secrets/oauth2-proxy.enc.yaml`, reflected into `paperless` and `ai`. Client secrets stay in `secrets/pocket-id-sso.enc.yaml`. oauth2-proxy treats each value as URL-safe base64 of 16, 24, or 32 bytes. `+` or `/` from `openssl rand -base64` is rejected.

## Rebuild

1. Keep the cookie secret. A new value signs everyone out. If you must mint one:

```sh
node -e 'console.log(require("crypto").randomBytes(32).toString("base64url"))'
task sops:edit -- secrets/oauth2-proxy.enc.yaml
```

2. On each existing Pocket ID client, add the gate callback. See [pocket-id](pocket-id.md).
3. Point the tunnel routes at the headless services. See [cloudflared](cloudflared.md).
4. Reconcile.

## Check

The three HelmReleases named `oauth2-proxy` are Ready. Opening an app host without a Pocket ID session redirects to Pocket ID. That request does not show up in the app log.

## Restore

No claim. Keep the cookie secret.
