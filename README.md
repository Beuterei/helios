# cluster

Flux GitOps for the Helios single-node k3s cluster. NixOS owns the host (k3s, NVIDIA, CDI); this repo owns what runs on it.

Bootstrap Flux once with `--path clusters/helios`. After that, push and reconcile.

## Layout

| Path | Role |
| --- | --- |
| `clusters/helios` | Flux Kustomizations Flux watches |
| `platform` | GPU device plugin. Must be Ready before GPU workloads |
| `apps` | Workloads. Applied after platform |
| `charts/generic-cdi-plugin` | Local chart: advertise host CDI devices to the kubelet |
| `Taskfile.yml` | `build`, `diff`, `reconcile`, `status` |

## Apply order

`GitRepository` `flux-system` syncs this repo. `clusters/helios` points Flux at:

1. **platform** — CDI plugin DaemonSet (`nvidia.com/gpu-all`)
2. **apps** — waits for platform, then workloads

## Operate

From this directory. Defaults to `/etc/rancher/k3s/k3s.yaml`.

```sh
task build        # render layers, catch YAML mistakes
task diff         # working tree vs what Flux applied
task reconcile    # fetch HEAD and apply now
task status       # Flux kustomizations and HelmReleases
```
