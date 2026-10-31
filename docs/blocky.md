# blocky

LAN and cluster DNS. Cluster pods forward outside names through it; `cluster.local` stays with CoreDNS (`platform/coredns-custom.yaml`). No claim. Blocklists are downloaded at start.

Flux applies `apps/blocky.yaml` in namespace `network`.

## Rebuild

1. Reserve this node's LAN address on the gateway. The LoadBalancer and the names Blocky answers are set in `apps/blocky.yaml`.
2. Point LAN DHCP DNS at that address.
3. Reconcile.

## Check

HelmRelease `blocky` is Ready.

```sh
kubectl -n network get svc blocky
```
