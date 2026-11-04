# volume-backup

Copies bound claim directories to S3. CronJobs in namespace `backup` run backup, prune, and check, on the schedules in the chart values. A backup run takes one namespace at a time: it checkpoints Postgres, freezes the pods that mount a claim, copies, thaws, and writes one restic snapshot tagged with the namespace. The upload happens after the thaw, so writers stay frozen only for the local copy.

## Flux

Flux applies `platform/volume-backup/helmrelease.yaml` from `charts/volume-backup`. It waits for namespaces and secrets and does not gate apps.

Every bound claim is copied except the exclude list on that HelmRelease, so a new claim is included on the next run. The local copy needs about as much free disk as the largest namespace.

## Secrets

The backup S3 SOPS secret holds the repository credentials and the Healthchecks ping URLs. Backup, prune, and check each ping at start, on success, and on failure. [reloader](reloader.md) does not roll a CronJob that is not running.

## Rebuild

1. Fill the secret before the first reconcile, because the backup job fails until restic can create the repository.

```sh
task sops:edit -- secrets/backup-s3.enc.yaml
```

2. Reconcile, and wait until HelmRelease `volume-backup` is Ready and the target claims are Bound.
3. Restore each namespace that should come back. See [open-webui](open-webui.md), [paperless](paperless.md), [norish](norish.md), and [pocket-id](pocket-id.md). Keep the Paperless, Norish, and Pocket ID secrets from before the restore.

## Check

HelmRelease `volume-backup` is Ready, CronJob `restic-backup` exists, and the latest Job has not failed on a missing repository.

## Restore

The claims must already exist and be Bound. The restore freezes the namespace, moves the live files aside, copies the snapshot, and deletes the aside copy only after the copy succeeds. A snapshot id may be passed, and the default is the latest snapshot tagged with the namespace.

```sh
task backup:restore -- <namespace>
```
