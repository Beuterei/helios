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
| **Platform** | Cluster operators, the Cloudflare Tunnel, and node plugins | User-facing apps, Certificates, Secrets |
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
| `platform` | CDI plugin and CoreDNS override |
| `platform/cert-manager` | cert-manager HelmRelease (own Flux layer so CRDs are Ready before certs) |
| `platform/cloudflared` | cloudflared HelmRelease and its egress allowlist (own Flux layer; waits for the tunnel token) |
| `apps` | Workload HelmReleases |
| `certs` | Let's Encrypt `ClusterIssuer` and `*.luisbeu.de` `Certificate` |
| `secrets` | Cloudflare DNS-01 token and tunnel token. Matches `.sops.yaml`; commit only `*.enc.yaml` |
| `charts/generic-cdi-plugin` | Chart for the CDI plugin; the release lives in `platform` |
| `Taskfile.yml` | `build`, `diff`, `reconcile`, `status` |

## Apply order

`GitRepository` `flux-system` syncs this repo. `clusters/helios` points Flux at:

1. **namespaces** — names exist before anything targets them
2. **sources** — chart repos; no dependencies
3. **platform** — CDI plugin and CoreDNS. No dependencies
4. **cert-manager** — waits for namespaces and sources, then the operator
5. **secrets** — waits for namespaces, then decrypts SOPS
6. **certs** — waits for namespaces, cert-manager, and secrets, then requests certificates
7. **apps** — waits for namespaces, sources, platform, and certs, then workloads
8. **cloudflared** — waits for namespaces, sources, and secrets, then the remotely managed tunnel

Apps that mount the TLS secret wait for **certs**.

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
