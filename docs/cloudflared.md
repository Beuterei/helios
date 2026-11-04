# cloudflared

Runs the connector for the remotely managed Cloudflare Tunnel `helios`. Hostnames and origin addresses are set in the Cloudflare dashboard, so this repo only runs the connector. LAN clients use Blocky, not the tunnel.

## Flux

Flux applies `platform/cloudflared/` in namespace `network`.

A dashboard route connects only when `platform/cloudflared/networkpolicy.yaml` allows its origin, so a new destination goes into that policy in the same change. The ingress controller stays off that list, because allowing it would publish every Ingress.

## Secrets

The Cloudflare tunnel SOPS secret holds the tunnel token.

## Rebuild

The token in git is reused when SOPS decrypts it and the tunnel still exists. Create a tunnel only when that one is gone:

1. In the [Cloudflare dashboard](https://dash.cloudflare.com/), go to **Networking** > **Tunnels** and select **Create a tunnel**.
2. Name it `helios`.
3. Choose **Docker**. Copy the token, not the install command.
4. Replace the token key in the secret.

```sh
task sops:edit -- secrets/cloudflare-tunnel-token.enc.yaml
```

5. Push and `task reconcile`.
6. On the tunnel, add a published application for each public hostname. The names are the hosts of the apps below.
7. Point each one at the headless service the egress policy allows, so the destination is the pod. The port is the one in that chart's `templates/service.yaml`.

- Pocket ID host (`publicURL` in `charts/pocket-id/values.yaml`): `http://pocket-id-tunnel.pocket-id.svc.cluster.local:<port>`
- Norish host (`host` in `apps/oauth2-proxy-norish.yaml`): `http://oauth2-proxy-tunnel.norish.svc.cluster.local:<port>`

Paperless, Open WebUI, and WebDAV are LAN only and stay off the tunnel. Neither the ingress controller nor an app service is an origin.

## Check

HelmRelease `cloudflared` is Ready, and the connector log contains `Registered tunnel connection`.
