# generic-cdi-plugin

Registers the host NVIDIA CDI devices with the kubelet so Ollama can request that device. It has no Secret and no claim.

## Flux

Flux applies `platform/generic-cdi-plugin.yaml` in `kube-system`, from `charts/generic-cdi-plugin`.

## Rebuild

1. The NixOS host has written the CDI spec the chart mounts.
2. Reconcile.

## Check

HelmRelease `generic-cdi-plugin` is Ready, and the node advertises the device the chart registers.
