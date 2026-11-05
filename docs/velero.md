# velero

Copies mounted claim files to object storage. Cron schedules in the HelmRelease run a daily backup and a monthly backup. Kopia stores the file data. Postgres claims are left out for CloudNativePG. The paperless broker, the norish cache, and the Ollama claim are left out because those files can be rebuilt or pulled. A claim is copied only while a pod has it mounted. The copy reads the live files, so a file can be mid-write. Open WebUI keeps its accounts in SQLite on the claim. Pocket ID accounts are in Postgres, and that claim is left out.

## Flux

Flux applies `platform/velero/helmrelease.yaml` from the vmware-tanzu chart. It waits for namespaces and secrets and does not gate apps.

A namespace is included unless the schedule excludes it. A claim in an included namespace is copied unless it carries the skip label.

## Secrets

The Velero SOPS secret holds the object storage key. The bucket and the prefix are in the HelmRelease. Backup objects sit under that prefix. The bucket root holds the restic repository. The Healthchecks SOPS secret holds the success URL. A completed daily backup pings it once. Healthchecks alerts when that ping does not arrive, so a failed backup and a dead pinger raise the same alarm. The Healthchecks grace has to cover the backup.

## Rebuild

1. Fill the secret before the first reconcile, because the backup storage location stays unavailable until the key works.

```sh
task sops:edit -- secrets/velero.enc.yaml
```

2. Reconcile, and wait until HelmRelease `velero` is Ready and the target claims are Bound.
3. Restore each namespace that should come back. See [open-webui](open-webui.md), [paperless](paperless.md), [norish](norish.md), and [pocket-id](pocket-id.md).

## Check

HelmRelease `velero` is Ready, BackupStorageLocation `default` is Available, and the latest Backup from Schedule `velero-daily` is Completed. CronJob `velero-healthchecks` has not failed, and Healthchecks shows that success.

## Restore

The claims must already be Bound. The task suspends the namespace's HelmReleases and deletes their workloads so nothing holds the claims. It restores the pods from the backup, and the node agent writes the backed-up files into the claims those pods mount. Claims with the skip label are not in the backup, so their files stay. The task then deletes the restored pods and resumes the HelmReleases, which start the apps. A failed restore leaves the HelmReleases suspended.

A backup name may be passed. The default is the latest completed backup from Schedule `velero-daily`.

```sh
task backup:restore -- <namespace>
```
