# ollama

GPU inference for Open WebUI, Paperless, and Norish. The chart pulls the models, and they are not backed up. Install does not wait on the pull, so the HelmRelease can be Ready while a download is still running. Open WebUI is in the same namespace, and Paperless and Norish are the only other callers.

## Flux

Flux applies `apps/ollama.yaml` in namespace `ai`. The device comes from [generic-cdi-plugin](generic-cdi-plugin.md), and `volume-backup` excludes this claim.

## Rebuild

1. The CDI plugin is Ready and the node advertises the GPU device.
2. Reconcile and wait for the pulls.

## Check

```sh
kubectl -n ai exec deploy/ollama -- ollama list
```

The models listed in `apps/ollama.yaml` are present once the pulls finish.
