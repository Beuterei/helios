# open-webui

Chat UI in front of in-cluster Ollama. Accounts and chats live on its claim, which [velero](velero.md) copies.

## Flux

Flux applies `apps/open-webui.yaml` in namespace `ai`. TLS comes from [cert-manager](cert-manager.md). The [session gate](oauth2-proxy.md) owns the Ingress, and the host is LAN only, not a tunnel route.

## Secrets

The Open WebUI gate SOPS secret holds the Pocket ID client secret and the gate cookie secret for this namespace only.

## Sign-in

Sign-in is [Pocket ID](pocket-id.md), and the username form is off. A user needs the Pocket ID group `open_webui` or `admins`. Accounts are not merged by email.

## Rebuild

1. The reflected TLS secret is in this namespace.
2. Ollama is pulling the models its chart lists.
3. Reconcile and wait until the claim is Bound.
4. Restore the claim before signing in. On an empty claim, sign in first with a Pocket ID user in the `admins` group, because that account becomes the admin. Later users are normal users.

## Check

HelmRelease `open-webui` is Ready, and its Ingress host answers.

## Restore

```sh
task backup:restore -- ai
```

The claim must already be Bound. The Ollama claim is left in place, and the task restarts Ollama because both apps share the namespace. See [velero](velero.md).
