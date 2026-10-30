# cluster

Flux GitOps for the Helios single-node k3s cluster. NixOS owns the host (k3s, NVIDIA, CDI); this repo owns what runs on it.

Bootstrap Flux once with `--path clusters/helios`. After that, push and reconcile.

## Concerns

One directory, one kind of object. Put new YAML in the directory that matches the kind, not the feature it supports.

| Concern | Owns | Does not own |
| --- | --- | --- |
| **Apply graph** | Flux `Kustomization` objects: path, `dependsOn`, decryption | HelmReleases, Namespaces, Secrets, charts |
| **Namespaces** | `Namespace` objects | Anything that lives inside those namespaces |
| **Sources** | `HelmRepository` / `OCIRepository` | The HelmReleases that consume them |
| **Platform** | Cluster operators and node plugins | User-facing apps, Certificates, Secrets |
| **Apps** | Workload HelmReleases | Namespaces, chart sources, ClusterIssuers, kube-system config |
| **Secrets** | SOPS-encrypted `Secret` manifests (`*.enc.yaml`) | ClusterIssuers, Certificates, plaintext |
| **Certs** | `ClusterIssuer` and `Certificate` | cert-manager itself, Ingress, apps that mount the TLS secret |
| **Charts** | Local Helm chart source in this repo | The HelmRelease that installs the chart |

Flux layers (`clusters/helios/*.yaml`) wire these together. They do not contain the objects they apply.

## Layout

| Path | Concern |
| --- | --- |
| `clusters/helios` | Apply graph, including `flux-system` |
| `namespaces` | `ai`, `network`, `cert-manager` |
| `sources` | Chart repos for ollama, open-webui, blocky, cert-manager |
| `platform` | CDI plugin and CoreDNS override, both in `kube-system` |
| `platform/cert-manager` | cert-manager HelmRelease (own Flux layer so CRDs are Ready before certs) |
| `apps` | HelmReleases: ollama, open-webui, blocky |
| `certs` | Let's Encrypt `ClusterIssuer` and `*.luisbeu.de` `Certificate` |
| `secrets` | Cloudflare DNS-01 token. Matches `.sops.yaml`; commit only `*.enc.yaml` |
| `charts/generic-cdi-plugin` | Chart for the CDI plugin; the release lives in `platform` |
| `Taskfile.yml` | `build`, `diff`, `reconcile`, `status` |

## Apply order

`GitRepository` `flux-system` syncs this repo. `clusters/helios` points Flux at:

1. **namespaces** — names exist before anything targets them
2. **sources** — chart repos; no dependencies
3. **platform** — CDI plugin and CoreDNS in `kube-system`. No dependencies
4. **cert-manager** — waits for namespaces and sources, then the operator
5. **secrets** — waits for namespaces, then decrypts SOPS
6. **certs** — waits for namespaces, cert-manager, and secrets, then requests certificates
7. **apps** — waits for namespaces, sources, platform, and certs, then workloads

`open-webui` mounts the TLS secret that **certs** creates, so apps wait for certs.

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
