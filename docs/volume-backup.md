# volume-backup

Copies bound claim directories to S3. Three Deployments in namespace `backup` run backup, prune, and check. Backup also runs once when its pod starts.

Flux applies `platform/volume-backup/helmrelease.yaml` from `charts/volume-backup`. It waits for namespaces and secrets. It does not gate apps.

Every bound claim is copied except the exclude list on that HelmRelease. A claim added later is included on the next run. Containers that mount an included claim are frozen while those directories are copied, then unfrozen while restic uploads. The copy needs free disk about as large as the data being copied.

Repository credentials are `secrets/backup-s3.enc.yaml`. Healthcheck URL keys in that secret may be empty. Endpoint options are chart values.

## Rebuild

1. Fill the secret before the first reconcile if it is still the example. The backup pod exits until restic can create the repository; the next restart reads the updated secret.

```sh
task sops:edit -- secrets/backup-s3.enc.yaml
```

2. Reconcile. Wait until HelmRelease `volume-backup` is Ready and the target claims are Bound.
3. Restore each claim that should come back. See [open-webui](open-webui.md) and [paperless](paperless.md). Keep the Paperless secret from before the restore.

## Check

HelmRelease `volume-backup` is Ready. The backup pod is not crash-looping on a missing repository.

## Restore

The claim must already exist and be Bound. This freezes writers, replaces the claim directory with the snapshot, and restarts them. A snapshot id may be passed as the third argument; the default is `latest`.

```sh
task backup:restore -- <namespace> <claim>
```
