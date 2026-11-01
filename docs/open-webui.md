# open-webui

Chat UI in front of in-cluster Ollama. Accounts, chats, and API keys live on its claim. [volume-backup](volume-backup.md) copies it.

Flux applies `apps/open-webui.yaml` in namespace `ai`. TLS comes from [cert-manager](cert-manager.md).

Sign-in is [authentik](authentik.md). An account with the same email is the existing user. The username form is off.

## Rebuild

1. The reflected TLS secret is in this namespace.
2. Ollama is pulling the models its chart lists.
3. Reconcile.
4. Restore the claim before signing in. On an empty claim, sign in as `akadmin` first. That account is the admin. Other Authentik users are normal users.

## Check

HelmRelease `open-webui` is Ready. Its Ingress host answers.

## Restore

```sh
task backup:restore -- ai open-webui
```

The claim must already be Bound. The restore replaces the directory and restarts the writers.
