# blocky

LAN and cluster DNS. Cluster pods forward outside names through it; `cluster.local` stays with CoreDNS (`platform/coredns-custom.yaml`). No claim. Blocklists are downloaded at start.

Flux applies `dns/blocky.yaml` in namespace `network`.

## Rebuild

1. Reserve this node's LAN address on the gateway. The LoadBalancer and the names Blocky answers are set in `dns/blocky.yaml`.
2. Point LAN DHCP DNS at that address.
3. Reconcile.

## Check

HelmRelease `blocky` is Ready.

```sh
kubectl -n network get svc blocky
```

## Break-glass

If Blocky is down, CoreDNS still forwards outside names to it and pods cannot resolve. Suspend the override, delete it, and restart CoreDNS so it uses the host resolver until Blocky is back. Then resume the layer.

```sh
flux suspend kustomization platform
kubectl -n kube-system delete configmap coredns-custom
kubectl -n kube-system rollout restart deploy/coredns
```

```sh
flux resume kustomization platform
```
