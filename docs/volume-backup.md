# volume-backup

Copies bound claim directories to S3. CronJobs in namespace `backup` run backup, a weekly prune, and a daily check. Each run takes one namespace at a time: it checkpoints Postgres, freezes the pods that mount a claim, copies, thaws, and writes one restic snapshot tagged with the namespace. The upload happens after the thaw.

Flux applies `platform/volume-backup/helmrelease.yaml` from `charts/volume-backup`. It waits for namespaces and secrets. It does not gate apps.

Every bound claim is copied except the exclude list on that HelmRelease. A claim added later is included on the next run. The copy needs free disk about as large as the largest namespace.

Repository credentials and the Healthchecks ping URLs are `secrets/backup-s3.enc.yaml`. Backup, prune, and check each ping at start, on success, and on failure. Schedules are chart values. [reloader](reloader.md) does not roll a CronJob that is not running.

## Rebuild

1. Fill the secret before the first reconcile. The backup job fails until restic can create the repository.

```sh
task sops:edit -- secrets/backup-s3.enc.yaml
```

2. Reconcile. Wait until HelmRelease `volume-backup` is Ready and the target claims are Bound.
3. Restore each namespace that should come back. See [open-webui](open-webui.md), [paperless](paperless.md), [norish](norish.md), and [pocket-id](pocket-id.md). Keep the Paperless, Norish, and Pocket ID secrets from before the restore.

## Check

HelmRelease `volume-backup` is Ready. CronJob `restic-backup` exists. The latest Job is not failed on a missing repository.

## Restore

The claims must already exist and be Bound. This freezes the namespace, moves the live files aside, copies the snapshot, and deletes the aside only after the copy succeeds. A snapshot id may be passed; the default is the latest snapshot tagged with the namespace.

```sh
task backup:restore -- <namespace>
```
