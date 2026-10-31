# generic-cdi-plugin

Registers the host NVIDIA CDI devices with the kubelet. Ollama requests that device. No Secret and no claim.

Flux applies `platform/generic-cdi-plugin.yaml` in `kube-system`, from `charts/generic-cdi-plugin`.

## Rebuild

1. The NixOS host must already have written the CDI spec the chart mounts.
2. Reconcile.

## Check

HelmRelease `generic-cdi-plugin` is Ready, and the node advertises the device the chart registers.
