# open-webui

Chat UI in front of in-cluster Ollama. Accounts, chats, and API keys live on its claim. [volume-backup](volume-backup.md) copies it.

Flux applies `apps/open-webui.yaml` in namespace `ai`. TLS comes from [cert-manager](cert-manager.md). The Ingress is the [session gate](oauth2-proxy.md). It is LAN only, not a tunnel route.

Sign-in is [Pocket ID](pocket-id.md). An account with the same email is the existing user. The username form is off.

## Rebuild

1. The reflected TLS secret is in this namespace.
2. Ollama is pulling the models its chart lists.
3. Reconcile.
4. Restore the claim before signing in. On an empty claim, sign in with a Pocket ID user in the `admins` group first. That account is the admin. Other users are normal users.

## Check

HelmRelease `open-webui` is Ready. Its Ingress host answers.

## Restore

```sh
task backup:restore -- ai
```

The claim must already be Bound. The snapshot is the `ai` namespace. `ollama` is not in it. The restore replaces the directory and restarts the writers.
