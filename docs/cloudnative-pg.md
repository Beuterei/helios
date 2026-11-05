# cloudnative-pg

Postgres for Paperless, Norish, and Pocket ID. Each app chart has one `Cluster` named `postgres` and one instance. The primary Service is `postgres-rw`. Velero skips the volume. Base backups and WAL go to the object store named in that chart.

## Flux

Flux applies `platform/cloudnative-pg` in namespace `cnpg-system`. The operator chart is `cloudnative-pg` and the backup chart is `plugin-barman-cloud`, both from the cloudnative-pg Helm repository. The plugin creates its certificates with cert-manager. App HelmReleases wait for this layer. The operator clock is `Europe/Berlin`, which is the clock for the backup cron in the app charts.

## Secrets

The SOPS secret in `cnpg-system` holds the object store access key, secret key, and region. Reflector copies it into `paperless`, `norish`, and `pocket-id`. Each database has its own SOPS secret, named in that app chart. CloudNativePG reads the keys `username` and `password` from it, and the app reads `password` from the same secret.

## Check

HelmReleases `cloudnative-pg` and `plugin-barman-cloud` are Ready. Cluster `postgres` in each app namespace is Healthy, and its daily `Backup` reaches Completed.

## Restore

Velero does not have these databases. A rebuilt cluster from git is empty. To bring one database back, suspend that app HelmRelease, delete Cluster `postgres`, and apply a Cluster with the same name, storage, owner secret, and plugin, and with `bootstrap.recovery` pointed at the chart's ObjectStore (`serverName` `postgres`). That Cluster carries annotation `cnpg.io/skipEmptyWalArchiveCheck: enabled`, because the WAL archive for that server already holds the backup. The chart bootstraps with `initdb`, and that field cannot change on an existing cluster, so the HelmRelease stays suspended while the recovered cluster is in use.
