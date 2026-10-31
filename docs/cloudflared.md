# cloudflared

Runs a remotely managed Cloudflare Tunnel named `helios`. Hostnames and origin addresses are set in the Cloudflare dashboard. This repo only runs the connector. LAN clients use Blocky, not the tunnel.

Flux applies `platform/cloudflared/` in namespace `network`. The token is `secrets/cloudflare-tunnel-token.enc.yaml`.

A dashboard route connects only when its origin is allowed by `platform/cloudflared/networkpolicy.yaml`. Add that destination to the policy in the same change. Leave the ingress controller off that list; allowing it would publish every Ingress.

## Rebuild

The token in git is reused when SOPS decrypts and the tunnel still exists. Create a tunnel only when that one is gone:

1. In the [Cloudflare dashboard](https://dash.cloudflare.com/), go to **Networking** > **Tunnels** and select **Create a tunnel**.
2. Name it `helios`.
3. Choose **Docker**. Copy the token, not the install command.
4. Replace the token key in `secrets/cloudflare-tunnel-token.enc.yaml`.

```sh
task sops:edit -- secrets/cloudflare-tunnel-token.enc.yaml
```

5. Push and `task reconcile`.
6. On the tunnel, add a published application for each public hostname. Those names are the Ingress hosts in the app manifests.
7. Set the service to an address the egress policy allows.

## Check

HelmRelease `cloudflared` is Ready. The connector log contains `Registered tunnel connection`.
