# blocky

LAN and cluster DNS. Cluster pods forward outside names through it while `cluster.local` stays with CoreDNS (`platform/coredns-custom.yaml`). It has no claim, and the blocklists are downloaded at start.

## Flux

Flux applies `dns/blocky.yaml` in namespace `network`. The pinned ClusterIP and the names Blocky answers are set there, and the LoadBalancer listens on this node.

## Rebuild

1. Reserve this node's LAN address on the gateway, because the mapping in `dns/blocky.yaml` answers with that address.
2. Point LAN DHCP DNS at that address.
3. Reconcile.

## Check

HelmRelease `blocky` is Ready, and its pinned ClusterIP matches the forward target in `platform/coredns-custom.yaml`.

```sh
kubectl -n network get svc blocky
name=$(awk '/mapping:/{getline; print $1; exit}' dns/blocky.yaml | tr -d ':')
ip=$(kubectl -n network get svc blocky -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
dig +short @"$ip" "$name"
```

## Break-glass

While Blocky is down, CoreDNS still forwards outside names to it, so pods cannot resolve them. Suspend the override, delete it, and restart CoreDNS so it uses the host resolver until Blocky is back. Then resume the layer.

```sh
flux suspend kustomization platform
kubectl -n kube-system delete configmap coredns-custom
kubectl -n kube-system rollout restart deploy/coredns
```

```sh
flux resume kustomization platform
```
