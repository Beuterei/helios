# reloader

Rolls a pod when a Secret that pod reads changes. The process then starts with the new values. ConfigMap changes do not roll pods.

Flux applies `platform/reloader.yaml` in `kube-system`. It watches every namespace. A workload opts out with `reloader.stakater.com/auto: "false"`.

## Rebuild

1. Reconcile.

## Check

HelmRelease `reloader` is Ready. After a Secret edit, the pods that read it are a new age.
