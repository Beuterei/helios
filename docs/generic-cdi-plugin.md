# generic-cdi-plugin

Registers the host NVIDIA CDI devices with the kubelet so Ollama can request that device. It has no Secret and no claim.
Registers host CDI devices with the kubelet, so a pod requests a device as a resource instead of running privileged. One release reads one CDI spec: `generic-cdi-plugin` registers the NVIDIA devices for Ollama, and `generic-cdi-plugin-zigbee` registers the ConBee for Zigbee2MQTT. It has no Secret and no claim.

## Flux

Flux applies `platform/generic-cdi-plugin.yaml` in `kube-system`, from `charts/generic-cdi-plugin`.
Flux applies `platform/generic-cdi-plugin.yaml` and `platform/generic-cdi-plugin-zigbee.yaml` in `kube-system`, from `charts/generic-cdi-plugin`. Each release sets the spec path the chart mounts.

## Rebuild

1. The NixOS host has written the CDI spec the chart mounts.
2. Reconcile.
1. The NixOS host has written both CDI specs. nvidia-container-toolkit writes the NVIDIA spec, and `machines/helios.nix` in nixos-config writes the ConBee spec.
2. Restart k3s once after the ConBee spec first appears, so containerd reads the new spec directory.
3. Reconcile.

## Check

HelmRelease `generic-cdi-plugin` is Ready, and the node advertises the device the chart registers.
Both HelmReleases are Ready, and the node advertises the resource each release registers.

```sh
kubectl get node -o jsonpath='{.items[0].status.allocatable}'
```