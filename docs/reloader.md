# reloader

Rolls a pod when a Secret that pod reads changes, so the process starts with the new values. One watcher covers every namespace, so no app installs its own. ConfigMap changes do not roll pods.

A database password is not applied by that restart, which only makes the process read the new value. Run `ALTER USER` with the new password first, then change the Secret.

## Flux

Flux applies `platform/reloader.yaml` in `kube-system`. A workload opts out with `reloader.stakater.com/auto: "false"`.

## Rebuild

1. Reconcile.

## Check

HelmRelease `reloader` is Ready. After a Secret edit, the pods that read it restart.
