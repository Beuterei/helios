# home-assistant

Home Assistant with Zigbee2MQTT, Mosquitto, and a CloudNativePG recorder database. Git holds the YAML configuration, the dashboards, and the pinned custom cards and integrations, so the claim keeps only what the UI writes: users, devices, areas, and integration setups. The ConBee reaches Zigbee2MQTT through the zigbee [generic-cdi-plugin](generic-cdi-plugin.md) release, so neither pod is privileged.

## Flux

Flux applies `apps/home-assistant.yaml` in namespace `home-assistant`, from `charts/home-assistant`. The Home Assistant files live in that chart's `files/`: `configuration.yaml` holds the base setup, `packages/` holds one package per room or concern, and the dashboards are YAML. A change to any of them rolls the pod, so it takes effect on the next reconcile.

Home Assistant keeps its HTTP settings in storage and ignores `http:` in YAML, so `http.json` in the same folder carries the reverse-proxy settings. An init container writes it as the confirmed config on every start, which overwrites an HTTP change made in the UI.

An init container installs the custom cards and integrations pinned in `hpm.json` on every start. It keeps the installed set when GitHub is unreachable, so a restart does not depend on GitHub. Change a package with `hpm add <repo>@<tag>` against that file, because `hpm` pins the files of that release.

Zigbee2MQTT's `configuration.yaml` replaces the claim copy on every start, so rename a device in git and not in the frontend. The friendly names are the MQTT topics the switch automations listen on.

Both hosts are Blocky mappings in `dns/blocky.yaml` and are left out of the tunnel, so they answer on the LAN only. Home Assistant runs on the pod network, so mDNS and SSDP find nothing. Devices are added by address, so each one has a DHCP reservation on the gateway.

## Secrets

The Home Assistant SOPS secret holds the coordinates, the door buzzer webhook id, and the hpm GitHub token. Keep the webhook id, because its callers hold it. The Zigbee2MQTT SOPS secret holds the network key and the frontend token. The key has to match the one on the coordinator, because a different key drops every paired device. The Mosquitto SOPS secret holds one password per broker user, and the Home Assistant password goes into the MQTT integration by hand. The database password is in the secret named by `postgres.secretName`.

```sh
task sops:decrypt -- secrets/mosquitto.enc.yaml
```

## Sign-in

Home Assistant uses its own accounts, and the Zigbee2MQTT frontend asks for the frontend token.

## Rebuild

1. The NixOS host has written the ConBee CDI spec, and the node advertises the zigbee resource. See [generic-cdi-plugin](generic-cdi-plugin.md).
2. The reflected TLS secret is in this namespace.
3. Before Zigbee2MQTT first starts, check the PAN ID, extended PAN ID, and channel in its `configuration.yaml`, and the network key, against the coordinator. The adapter rewrites the stick when any of them differ, and every paired device drops off. The `coordinator_backup.json` of a previous Zigbee2MQTT data directory holds them.
4. Reconcile and wait until the claims are Bound.
5. To keep the paired devices, copy the previous `database.db`, `coordinator_backup.json`, and `state.json` into the Zigbee2MQTT claim. Without `database.db`, Zigbee2MQTT ignores the devices it does not know, so each one is paired again.

    ```sh
    flux suspend helmrelease -n home-assistant home-assistant
    kubectl -n home-assistant scale deploy/zigbee2mqtt --replicas=0
    kubectl -n home-assistant run z2m-seed --image=busybox --restart=Never --overrides='{"spec":{"securityContext":{"runAsUser":1000,"runAsGroup":1000},"containers":[{"name":"z2m-seed","image":"busybox","command":["sleep","3600"],"volumeMounts":[{"name":"data","mountPath":"/data"}]}],"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"zigbee2mqtt-data"}}]}}'
    for f in database.db coordinator_backup.json state.json; do kubectl -n home-assistant cp "$f" z2m-seed:/data/"$f"; done
    kubectl -n home-assistant delete pod z2m-seed
    flux resume helmrelease -n home-assistant home-assistant
    ```

6. Open Home Assistant and create the owner account.
7. Add the integrations, because they live in the claim and not in git:
    - **MQTT**: broker `mosquitto`, user `homeassistant`, and the password from the Mosquitto SOPS secret.
    - **ESPHome**: each device from the esp-home repo by its reserved address, with that repo's API key. The Bluetooth proxy brings the toothbrush.
    - **Google Cast**: the Cast devices as known hosts.
    - **Mobile App**, **Fully Kiosk Browser**, and **UniFi Network** (clients tracked, wired clients and Ubiquiti devices not).
    - **Home Assistant Cloud**: sign in, link Google Assistant, and turn on the cloudhook for the door buzzer webhook under its webhooks. The cloudhook address is new for a new install, so hand it to the callers.
8. Assign devices to areas, set each person's device trackers, and set the internal URL in the companion app and the start URL in Fully Kiosk to the Home Assistant host.
9. Send automatic backups to Home Assistant Cloud only, or turn them off. Velero already copies the claim and CloudNativePG the database, so a local backup is copied twice.

## Check

HelmRelease `home-assistant` is Ready, and both Ingress hosts show a sign-in page. Zigbee2MQTT resumed the stored network instead of forming one:

```sh
kubectl -n home-assistant logs deploy/zigbee2mqtt | grep 'zigbee-herdsman started'
```

## Restore

Restore the Home Assistant and Zigbee2MQTT claims. The Mosquitto claim is left out, because Zigbee2MQTT republishes discovery and state. The database is CloudNativePG; see [cloudnative-pg](cloudnative-pg.md).

```sh
task backup:restore -- home-assistant
```

The claims must already be Bound. See [velero](velero.md).
