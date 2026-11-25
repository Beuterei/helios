# generic-cdi-plugin

Registers host CDI devices with the kubelet, so a pod requests a device as a resource instead of running privileged. One release reads one CDI spec: `generic-cdi-plugin` registers the NVIDIA devices for Ollama, and `generic-cdi-plugin-zigbee` registers the ConBee for Zigbee2MQTT. It has no Secret and no claim.

## Flux

Flux applies `platform/generic-cdi-plugin.yaml` and `platform/generic-cdi-plugin-zigbee.yaml` in `kube-system`, from `charts/generic-cdi-plugin`. Each release sets the spec path the chart mounts.

## Rebuild

1. The NixOS host has written both CDI specs. nvidia-container-toolkit writes the NVIDIA spec. A udev rule in `machines/helios.nix` of nixos-config writes the ConBee spec whenever the stick appears, because CDI needs the current device node and not the by-id symlink.
2. Reconcile.

## Check

Both HelmReleases are Ready, and the node advertises the resource each release registers.

```sh
kubectl get node -o jsonpath='{.items[0].status.allocatable}'
```
