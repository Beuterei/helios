# cluster

Flux GitOps for the Helios single-node k3s cluster. NixOS owns the host (k3s, NVIDIA, CDI); this repo owns what runs on it.

Bootstrap Flux once with `--path clusters/helios`. After that, push and reconcile.

## Concerns

One directory, one kind of object. Put new YAML in the directory that matches the kind, not the feature it supports.

| Concern | Owns | Does not own |
| --- | --- | --- |
| **Apply graph** | Flux `Kustomization` objects: path, `dependsOn`, decryption | HelmReleases, Secrets, charts |
| **Namespaces** | `Namespace` objects | Anything that lives inside them |
| **Sources** | `HelmRepository` / `OCIRepository` | The HelmReleases that consume them |
| **Platform** | Cluster operators, the Cloudflare Tunnel, node plugins, and volume backups | User-facing apps, Certificates, Secrets |
| **Apps** | Workload HelmReleases | Chart sources, ClusterIssuers, cluster config |
| **Secrets** | SOPS-encrypted `Secret` manifests (`*.enc.yaml`) | ClusterIssuers, Certificates, plaintext |
| **Certs** | `ClusterIssuer` and `Certificate` | cert-manager itself, Ingress, apps that mount the TLS secret |
| **Charts** | Local Helm chart source in this repo | The HelmRelease that installs the chart |

Flux layers (`clusters/helios/*.yaml`) wire these together. They do not contain the objects they apply.

## Layout

| Path | Concern |
| --- | --- |
| `clusters/helios` | Apply graph, including `flux-system` |
| `namespaces` | `Namespace` objects |
| `sources` | Chart repositories |
| `platform` | CDI plugin, CoreDNS override, and secret reflector |
| `platform/cert-manager` | cert-manager HelmRelease (own Flux layer so CRDs are Ready before certs) |
| `platform/cloudflared` | cloudflared HelmRelease and its egress allowlist (own Flux layer; waits for the tunnel token) |
| `platform/volume-backup` | restic backup, prune, and check (own Flux layer; waits for the S3 secret) |
| `apps` | Workload HelmReleases |
| `certs` | Let's Encrypt `ClusterIssuer` and `*.luisbeu.de` `Certificate` |
| `secrets` | Cloudflare tokens and the restic S3 secret. Matches `.sops.yaml`; commit only `*.enc.yaml` |
| `charts/generic-cdi-plugin` | Chart for the CDI plugin; the release lives in `platform` |
| `charts/volume-backup` | Chart for restic; the release lives in `platform/volume-backup` |
| `charts/paperless` | Chart for Paperless-ngx; the release lives in `apps` |
| `Taskfile.yml` | `build`, `diff`, `reconcile`, `status` |

## Apply order

`GitRepository` `flux-system` syncs this repo. `clusters/helios` points Flux at:

1. **namespaces** — names exist before anything targets them
2. **sources** — chart repos; no dependencies
3. **platform** — CDI plugin, CoreDNS, and the secret reflector. No dependencies
4. **cert-manager** — waits for namespaces and sources, then the operator
5. **secrets** — waits for namespaces, then decrypts SOPS
6. **certs** — waits for namespaces, cert-manager, and secrets, then requests certificates
7. **apps** — waits for namespaces, sources, platform, and certs, then workloads
8. **cloudflared** — waits for namespaces, sources, and secrets, then the remotely managed tunnel
9. **backups** — waits for namespaces and secrets, then restic

Apps that mount the TLS secret wait for **certs**. Backups do not gate apps.

## Cloudflare

The tunnel is remotely managed. Hostnames and routes are set in the Cloudflare dashboard. This repo only runs `cloudflared`. The zone is `luisbeu.de`.

1. In the [Cloudflare dashboard](https://dash.cloudflare.com/), go to **Networking** > **Tunnels** and select **Create a tunnel**.
2. Name it `helios`.
3. Choose **Docker**. Copy the token (`eyJ...`), not the install command.
4. Replace the example token in `secrets/cloudflare-tunnel-token.enc.yaml` with that token: `task sops:edit -- secrets/cloudflare-tunnel-token.enc.yaml`. The key is `stringData.token`.
5. Push and `task reconcile`. The example token does not connect.
6. On the tunnel, open **Routes** and select **Add route** > **Published application**.
7. Set the hostname to a name in `luisbeu.de`, for example `chat.luisbeu.de`.
8. Set the service to an address listed in `platform/cloudflared/networkpolicy.yaml`.
9. Open the hostname. Cloudflare terminates TLS. The connector is up when `task status` shows the `cloudflared` HelmRelease Ready.

## Backups

`mazzolino/restic` copies bound claim directories to S3. Three Deployments in `backup` run backup, prune, and check. Backup also runs once when its pod starts.

Every bound claim is copied except the `exclude` list in `platform/volume-backup/helmrelease.yaml`. A claim added later is included on the next run. Containers that mount an included claim are frozen while those directories are copied, then unfrozen while restic uploads. The copy needs free disk about as large as the data being copied. Replica counts stay as Flux set them.

The repository, keys, and healthcheck URLs are `secrets/backup-s3.enc.yaml`. Fill them before the first reconcile. The backup pod exits until restic can create the repository; the next restart reads the updated secret.

```sh
task sops:edit -- secrets/backup-s3.enc.yaml
```

Restore one claim from the latest snapshot, or pass a snapshot id as the third argument. The workload is frozen, the claim directory is replaced, then unfrozen.

```sh
task backup:restore -- <namespace> <claim>
```

## Operate

From this directory. Defaults to `/etc/rancher/k3s/k3s.yaml`.

```sh
task build        # render layers, catch YAML mistakes
task diff         # working tree vs what Flux applied
task reconcile    # fetch HEAD and apply now
task status       # Flux kustomizations and HelmReleases
```

SOPS uses the age key in `.sops.yaml`. Decrypt and edit need `sops` on `PATH`, plus `SOPS_AGE_KEY` or `SOPS_AGE_KEY_FILE`. The private key is not in this repo.

```sh
task sops:encrypt -- secrets/<name>.yaml       # write secrets/<name>.enc.yaml, delete plaintext
task sops:edit -- secrets/<name>.enc.yaml       # edit in $EDITOR, re-encrypt
task sops:decrypt -- secrets/<name>.enc.yaml    # print plaintext, write no file
```

Add the new `*.enc.yaml` to `secrets/kustomization.yaml`.
