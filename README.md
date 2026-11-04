# cluster

Flux GitOps for the Helios single-node k3s cluster. NixOS owns the host (k3s, NVIDIA, CDI); this repo owns what runs on it.

Bootstrap Flux once with `--path clusters/helios`. After that, push and reconcile.

## Concerns

One directory, one kind of object. Put new YAML in the directory that matches the kind, not the feature it supports.

| Concern | Owns | Does not own |
| --- | --- | --- |
| **Apply graph** | Flux `Kustomization` objects: path, `dependsOn`, decryption | HelmReleases, Secrets, charts |
| **Namespaces** | `Namespace` objects and the `edge` PriorityClass | Anything that lives inside a namespace |
| **Sources** | `HelmRepository` / `OCIRepository` | The HelmReleases that consume them |
| **DNS** | Blocky HelmRelease | The CoreDNS override, chart source, Namespace |
| **Platform** | Cluster operators, the Cloudflare Tunnel, node plugins, the CoreDNS override, and volume backups | User-facing apps, Blocky, Certificates, Secrets |
| **Apps** | Workload HelmReleases and NetworkPolicies for upstream charts | Chart sources, ClusterIssuers, cluster config |
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
| `dns` | Blocky HelmRelease. Applied before the CoreDNS override |
| `platform` | CDI plugin, CoreDNS override, secret reflector, and secret reloader |
| `platform/cert-manager` | cert-manager HelmRelease (own Flux layer so CRDs are Ready before certs) |
| `platform/cloudflared` | cloudflared HelmRelease and its egress allowlist (own Flux layer; waits for the tunnel token) |
| `platform/volume-backup` | restic backup, prune, and check (own Flux layer; waits for the S3 secret) |
| `apps` | Workload HelmReleases and NetworkPolicies for upstream charts |
| `certs` | Let's Encrypt `ClusterIssuer` and `Certificate` |
| `secrets` | Matches `.sops.yaml`; commit only `*.enc.yaml` |
| `charts/generic-cdi-plugin` | Chart for the CDI plugin; the release lives in `platform` |
| `charts/volume-backup` | Chart for restic; the release lives in `platform/volume-backup` |
| `charts/paperless` | Chart for Paperless-ngx; the release lives in `apps` |
| `charts/pocket-id` | Chart for Pocket ID; the release lives in `apps` |
| `charts/norish` | Chart for Norish; the release lives in `apps` |
| `charts/oauth2-proxy` | Chart for the Pocket ID session gate; the releases live in `apps` |
| `docs` | Rebuild procedure and docs for each service |
| `Taskfile.yml` | `build`, `diff`, `reconcile`, `status` |

## Apply order

`GitRepository` `flux-system` syncs this repo. `clusters/helios` points Flux at:

1. **namespaces** — names exist before anything targets them
2. **sources** — chart repos; no dependencies
3. **dns** — Blocky. Waits for namespaces and sources
4. **platform** — CDI plugin, CoreDNS override, the secret reflector, and the secret reloader. Waits for dns
5. **cert-manager** — waits for namespaces and sources, then the operator
6. **secrets** — waits for namespaces, then decrypts SOPS
7. **certs** — waits for namespaces, cert-manager, and secrets, then requests certificates
8. **apps** — waits for namespaces, sources, platform, certs, and secrets, then workloads
9. **cloudflared** — waits for namespaces, sources, and secrets, then the remotely managed tunnel
10. **backups** — waits for namespaces and secrets, then restic

Apps that mount the TLS secret wait for **certs**. Apps that read SOPS secrets wait for **secrets**. Backups do not gate apps.

## Services

One rebuild procedure per service, in `docs/`. Flux applies the manifests. The doc is the steps and state that are not in the YAML: tokens, dashboard routes, the host, and claim restores.

If the cluster is gone it can be recreated with:

1. Bring the NixOS host back: k3s, NVIDIA, the CDI spec the generic-cdi-plugin chart mounts, and this node's LAN address.
2. Bootstrap Flux with `--path clusters/helios`.
3. Create Secret `flux-system/sops-age` with data key `age.agekey` (the age private key). The public key is in `.sops.yaml`. Secrets in git decrypt with that key. Keep them when restoring claims.
4. `task reconcile`, then `task status`.
5. Follow the docs below for anything still outside git. Restore claim data after `volume-backup` is Ready and the claims are Bound.

| Service | Namespace | Doc |
| --- | --- | --- |
| generic-cdi-plugin | `kube-system` | [docs/generic-cdi-plugin.md](docs/generic-cdi-plugin.md) |
| reloader | `kube-system` | [docs/reloader.md](docs/reloader.md) |
| cert-manager | `cert-manager` | [docs/cert-manager.md](docs/cert-manager.md) |
| cloudflared | `network` | [docs/cloudflared.md](docs/cloudflared.md) |
| blocky | `network` | [docs/blocky.md](docs/blocky.md) |
| ollama | `ai` | [docs/ollama.md](docs/ollama.md) |
| pocket-id | `pocket-id` | [docs/pocket-id.md](docs/pocket-id.md) |
| open-webui | `ai` | [docs/open-webui.md](docs/open-webui.md) |
| paperless | `paperless` | [docs/paperless.md](docs/paperless.md) |
| norish | `norish` | [docs/norish.md](docs/norish.md) |
| oauth2-proxy | `norish`, `paperless`, `ai` | [docs/oauth2-proxy.md](docs/oauth2-proxy.md) |
| volume-backup | `backup` | [docs/volume-backup.md](docs/volume-backup.md) |

## Tools

These are the versions `task build` was written against. They are expected on `PATH`. flux-local is also found in `~/.local/bin`.

| Tool | Version |
| --- | --- |
| kubectl | 1.36.3 |
| kustomize | 5.8.1 |
| flux | 2.9.5 |
| helm | 3.20.2 |
| sops | 3.13.3 |
| task | 3.48.0 |
| shellcheck | 0.11.0 |
| flux-local | 8.4.0 |

## Operate

From this directory. Defaults to `/etc/rancher/k3s/k3s.yaml`.

```sh
task build        # render layers, HelmReleases, scripts, and SOPS files
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
