# oauth2-proxy

Session gate for Norish, Paperless, and Open WebUI. A request needs a Pocket ID session before the app container is contacted. Norish is also on the tunnel, while Paperless and Open WebUI are LAN only. Pocket ID itself stays open so the login can finish, and Paperless WebDAV keeps its own password.

## Flux

Flux applies one HelmRelease of `charts/oauth2-proxy` in each app namespace. Each app accepts its HTTP port only from its gate. Traefik can open every gate, and cloudflared can open only the Norish gate.

## Secrets

Each namespace has its own gate SOPS secret. The `client-secret` key is that app's Pocket ID client secret, and the `cookie-secret` key signs that gate's cookie. oauth2-proxy reads the cookie secret as URL-safe base64 of an AES key, so `+` or `/` from `openssl rand -base64` is rejected.

## Sign-in

An existing Pocket ID session is reused, but the first visit still sets the gate cookie and the app cookie. Pocket ID issues a refresh token on that sign-in, and each gate refresh checks the groups again. The gate cookie lifetime ends the session. Pocket ID leaves the email unverified, and the gate accepts that because sign-in is a passkey.

## Rebuild

1. Keep the cookie secrets, because a new value signs everyone out. To mint one:

```sh
node -e 'console.log(require("crypto").randomBytes(32).toString("base64url"))'
task sops:edit -- secrets/paperless-gate.enc.yaml
task sops:edit -- secrets/open-webui-gate.enc.yaml
task sops:edit -- secrets/norish-gate.enc.yaml
```

2. On each existing Pocket ID client, add the gate callback. See [pocket-id](pocket-id.md).
3. Point the tunnel routes at the headless services. See [cloudflared](cloudflared.md).
4. Reconcile.

## Check

Every HelmRelease named `oauth2-proxy` is Ready. Opening an app host without a Pocket ID session redirects to Pocket ID, and that request does not show up in the app log.

## Restore

No claim. Keep the cookie secrets.
