#!/usr/bin/bash
# Paperless maps the OIDC groups claim only onto groups that already exist, and never creates them.
# This creates each group in PAPERLESS_GROUPS_TO_CREATE and sets its permissions from its role.
# It then sets each Pocket ID account's groups from the claim stored on that account, limited to those groups.
# Paperless runs it from /custom-cont-init.d after migrations and before the web server.
set -euo pipefail

if [[ -z "${PAPERLESS_GROUPS_TO_CREATE:-}" ]]; then
  exit 0
fi

cd "${PAPERLESS_SRC_DIR}"

py=$(cat <<'PY'
import json
import os

from allauth.socialaccount.models import SocialAccount
from django.contrib.auth.models import Group
from django.contrib.auth.models import Permission
from django.db.models import Q

specs = json.loads(os.environ["PAPERLESS_GROUPS_TO_CREATE"])
names = [spec["name"] for spec in specs]

user_permissions = Permission.objects.filter(
    Q(content_type__app_label="documents")
    | Q(
        content_type__app_label="paperless",
        codename__in=["view_applicationconfiguration", "view_global_statistics"],
    )
    | Q(content_type__app_label="auth", codename__in=["view_user", "view_group"]),
)
admin_permissions = Permission.objects.exclude(content_type__app_label="admin")

for spec in specs:
    group, _created = Group.objects.get_or_create(name=spec["name"])
    role = spec["role"]
    if role == "admin":
        group.permissions.set(admin_permissions)
    elif role == "user":
        group.permissions.set(user_permissions)
    else:
        raise SystemExit(f"unknown group role {role}")
    print(f"{group.name}: {group.permissions.count()} permissions")

claim = os.environ.get("PAPERLESS_SOCIAL_ACCOUNT_SYNC_GROUPS_CLAIM", "groups")
allowed = set(names)
for account in SocialAccount.objects.select_related("user"):
    extra = account.extra_data or {}
    claimed = (
        extra.get(claim)
        or (extra.get("userinfo") or {}).get(claim)
        or (extra.get("id_token") or {}).get(claim)
        or []
    )
    if isinstance(claimed, str):
        claimed = [claimed]
    groups = list(Group.objects.filter(name__in=[name for name in claimed if name in allowed]))
    account.user.groups.set(groups)
    print(f"{account.user.username}: {', '.join(group.name for group in groups) or 'none'}")
PY
)

if [[ -n "${USER_IS_NON_ROOT:-}" ]]; then
  python3 manage.py shell -c "$py"
else
  s6-setuidgid paperless python3 manage.py shell -c "$py"
fi
