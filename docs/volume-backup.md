# volume-backup

Copies bound claim directories to S3. Three Deployments in namespace `backup` run backup, prune, and check. Backup also runs once when its pod starts.

Flux applies `platform/volume-backup/helmrelease.yaml` from `charts/volume-backup`. It waits for namespaces and secrets. It does not gate apps.

Every bound claim is copied except the exclude list on that HelmRelease. A claim added later is included on the next run. Containers that mount an included claim are frozen while those directories are copied, then unfrozen while restic uploads. The copy needs free disk about as large as the data being copied.

Repository credentials and the Healthchecks ping URLs are `secrets/backup-s3.enc.yaml`. Backup, prune, and check each ping at start, on success, and on failure. An interrupted backup pings the failure URL. Endpoint options are chart values. Those three pods read the secret when they start. [reloader](reloader.md) rolls them when it changes.

## Rebuild

1. Fill the secret before the first reconcile if it is still the example. The backup pod exits until restic can create the repository. A later edit rolls backup, prune, and check, and they start with the new values.

```sh
task sops:edit -- secrets/backup-s3.enc.yaml
```

2. Reconcile. Wait until HelmRelease `volume-backup` is Ready and the target claims are Bound.
3. Restore each claim that should come back. See [open-webui](open-webui.md), [paperless](paperless.md), and [norish](norish.md). Keep the Paperless and Norish secrets from before the restore.

## Check

HelmRelease `volume-backup` is Ready. The backup pod is not crash-looping on a missing repository.

## Restore

The claim must already exist and be Bound. This freezes writers, replaces the claim directory with the snapshot, and restarts them. A snapshot id may be passed as the third argument; the default is `latest`.

```sh
task backup:restore -- <namespace> <claim>
```
