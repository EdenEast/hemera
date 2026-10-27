# Immich upgrade plan

## Decision

Upgrade Immich server and machine learning together from `v3.2.4` to `v3.3.5`.
Keep PostgreSQL, VectorChord, pgvector, Valkey, storage paths, and machine-learning
settings unchanged for this deployment. Review and approve the final manifest diff
before changing files or deploying.

This is a plan, not an executed upgrade. Immich was excluded from the application
updates deployed on 2026-10-27.

## Verified baseline

Read-only checks against the cluster on 2026-10-27 found:

- Server and machine learning: `v3.2.4`, one ready replica each.
- PostgreSQL: `17.5`, one healthy CloudNativePG instance.
- Database image: `ghcr.io/tensorchord/cloudnative-vectorchord:17.5-0.4.3`.
- Installed extensions: VectorChord `0.4.3` and pgvector `0.8.0`.
- Database size: approximately 210 MB. This does not include the photo library.
- Valkey image: `docker.io/valkey/valkey:9.1-alpine`, with persistent AOF storage.
- Photo library: NFS `192.168.2.116:/mnt/Volume/Files/Media/Photos`, mounted at `/data`.
- Longhorn volumes: PostgreSQL 20Gi, machine-learning cache 10Gi, Valkey data 1Gi.
- No CloudNativePG backup configuration, successful-backup timestamp, or Backup
  resources were found for Immich. NFS snapshot and off-host backup coverage have
  not been verified.

The target release's source accepts PostgreSQL `>=14`, VectorChord `>=0.3 <2`,
and pgvector `>=0.5 <1`. The current versions satisfy those checks. Its supplied
Compose configuration also uses VectorChord `0.4.3` and Valkey 9. No database-image
upgrade is required for this application update.

Both target container tags were verified in GHCR for Linux AMD64 and ARM64.
Recheck their availability and release advisories when scheduling the upgrade.

## 1. Prepare and rehearse

Do not schedule the production change until these checks pass:

1. Review releases `v3.3.0` through `v3.3.5`, including security notices and any
   newer upgrade advisories. Record the deployed Git revision and running image
   digests, including the floating Valkey image's digest.
2. Record a baseline: login, asset and album counts, existing photo/video playback,
   search, people recognition, mobile backup, and background-job status. Identify
   any active uploads, imports, transcoding, or library scans.
3. Identify a private backup destination outside the production volumes. Confirm
   sufficient space for the database, the complete NFS library, and restore copies.
   A snapshot on the same storage system is not the only recovery copy.
4. Take an online database dump for rehearsal. Preserve roles, extension versions,
   application settings, required secrets, manifests, and image digests securely.
   Never commit credentials or database dumps.
5. Restore the dump into an isolated database using the same PostgreSQL/extension
   image. Use fresh volumes and a separate namespace. Do not reuse production
   PVCs, the production database, or the writable production NFS export.
6. Use a separate copy or clone of media storage for the rehearsal. Block external
   side effects and production-service access. Do not create public or Tailscale
   ingress automatically. Sealed Secrets are namespace-bound; provision test
   credentials privately rather than copying the production sealed manifest.
7. Run both `v3.3.5` application images against the restored database and isolated
   media copy. Verify migrations, startup, login, existing media, search, upload,
   and machine learning. Check memory use and startup time against current limits
   and probes. Do not enable new ML model revisions during this upgrade.
8. Rehearse recovery to `v3.2.4` using the pre-upgrade database and media copies.
   Record actual backup, migration, and restore times to size the maintenance window.

An archive listing is only an integrity check. A successful restore and application
check are required before treating the backup as a tested recovery path.

## 2. Enter maintenance and take the final recovery point

This phase requires a scheduled interruption and authorization to stop Immich.

1. Pause mobile backups, uploads, imports, scheduled scans, and other writers.
   Allow in-flight jobs to finish where practical; record any remaining queue.
2. Through Git and Flux, set both Immich application Deployments to zero replicas.
   Wait for their pods to terminate. Keep PostgreSQL and Valkey running. Do not
   suspend the shared `apps` Kustomization or scale unrelated applications.
3. Take the final database dump while application writers are stopped. For example,
   run from the repository development environment with an explicit private backup
   destination:

   ```sh
   direnv exec . bash -euo pipefail <<'SH'
   umask 077
   : "${BACKUP_DIR:?Set BACKUP_DIR to a private off-volume backup directory}"
   mkdir -p "$BACKUP_DIR"
   primary="$(kubectl -n immich get cluster immich-postgresql \
     -o jsonpath='{.status.currentPrimary}')"
   test -n "$primary"
   kubectl -n immich exec "$primary" -c postgres -- \
     pg_dump -U postgres -d immich -Fc > "$BACKUP_DIR/immich.dump.partial"
   test -s "$BACKUP_DIR/immich.dump.partial"
   kubectl -n immich exec -i "$primary" -c postgres -- \
     pg_restore --list < "$BACKUP_DIR/immich.dump.partial" > "$BACKUP_DIR/archive-list.txt"
   mv "$BACKUP_DIR/immich.dump.partial" "$BACKUP_DIR/immich.dump"
   kubectl -n immich exec "$primary" -c postgres -- \
     pg_dumpall -U postgres --globals-only > "$BACKUP_DIR/globals.sql"
   sha256sum "$BACKUP_DIR/immich.dump" "$BACKUP_DIR/globals.sql" \
     > "$BACKUP_DIR/SHA256SUMS"
   SH
   ```

4. Snapshot and back up the complete NFS photo tree at this same write-paused
   recovery point. Include originals, uploads, generated media, and any external
   libraries. Verify that backup storage is independent of the live export.
5. Preserve Valkey's persistent state using a tested backup method, recording any
   pending jobs. Do not casually clear its queue during upgrade or recovery.
   The ML cache is rebuildable; preserving it avoids model downloads during startup.
6. Verify backup completion and checksums. Encrypt backups containing private data
   or credentials. Record the Git revision, image digests, backup locations, and
   snapshot identifiers together. Do not resume writes if a required backup fails.

The dump recipe is for a newly chosen backup directory. Preserve earlier recovery
points rather than overwriting them on retries. Failed `.partial` files are not
valid backups.

## 3. Deploy the application-only update

The final permanent image diff is limited to `apps/immich/deployment.yaml`:

```diff
-          image: ghcr.io/immich-app/immich-server:v3.2.4
+          image: ghcr.io/immich-app/immich-server:v3.3.5
-          image: ghcr.io/immich-app/immich-machine-learning:v3.2.4
+          image: ghcr.io/immich-app/immich-machine-learning:v3.3.5
```

1. Keep both replicas at zero while preparing and validating the new image tags.
2. Render `apps/immich`, perform server-side dry-run validation, and inspect the
   diff. Leave database and Valkey images, environment variables, security contexts,
   resource limits, storage, and ingress unchanged.
3. Commit the approved image changes and restore both replicas to one through Git.
   Push to the branch actually watched by Flux, currently `main`.
4. Reconcile the source and `apps` Kustomization, then wait for both Deployments:

   ```sh
   direnv exec . flux reconcile kustomization apps --with-source --timeout=5m
   direnv exec . kubectl -n immich rollout status deployment/immich-server --timeout=10m
   direnv exec . kubectl -n immich rollout status deployment/immich-machine-learning --timeout=10m
   ```

5. Watch application logs and database health during migrations. Stop and investigate
   migration failures, unsupported extensions, repeated restarts, OOM kills, or
   unavailable media. A rollout timeout alone is not a reason to rerun migrations
   or restore data blindly.

## 4. Verify before reopening writes

TCP readiness alone is not sufficient evidence of a healthy Immich upgrade.

- Confirm both running images are `v3.3.5`, Flux has applied the intended revision,
  and PostgreSQL is healthy with the original image and extension versions.
- Check the server's `/api/server/ping` endpoint and authenticated login through
  the existing HTTPS address.
- Compare pre-upgrade asset and album counts. Open original photos and videos,
  thumbnails, search, albums, and people results. Confirm NFS ownership and access.
- In the controlled maintenance test, upload a disposable photo and verify thumbnail
  generation and ML processing. Delete the test asset through Immich afterwards.
- Confirm mobile clients connect and can back up. Check logs, failed jobs, restarts,
  memory use, and storage before resuming bulk work.
- Reopen normal uploads only after acceptance. Retain the recovery point and monitor
  through a normal upload and background-processing cycle.

## 5. Recovery if acceptance fails

Treat a database migration as potentially irreversible by an image downgrade.

1. Stop application writers again through the maintenance replica settings in Git.
   Reconcile Flux and confirm pods have stopped before restoring anything.
2. Preserve logs and a separate copy of the failed state for diagnosis. Keep the
   original backup intact.
3. If failure occurred before migrations or storage changes, establish that fact
   from evidence before considering an image-only revert.
4. Otherwise, use the rehearsed procedure to restore the pre-upgrade database into
   a fresh compatible PostgreSQL cluster/volume. Recover the matching NFS and
   Valkey state as required. Never restore a dump over an active migrated database.
5. Revert only the Immich image changes to `v3.2.4` in Git and point the application
   at the verified restored database. Reconcile, verify, then reopen writes.
6. Any uploads accepted after the recovery point need separate recovery. Restoring
   an older database and photo snapshot can discard those newer changes.

Restoring data or switching database endpoints requires its own reviewed recovery
commands. Do not use `kubectl rollout undo` as a substitute for database recovery.

## Separate follow-up maintenance

After the application upgrade is stable, review these independently:

- Pin and update Valkey to `9.1.3-alpine`, preserving the existing data format and queue.
- Update PostgreSQL within major version 17 and review VectorChord/pgvector separately.
  Do not combine a PostgreSQL major upgrade with this application release.
- Add scheduled off-cluster database backups and routine restore tests, and verify
  independent backup coverage for the NFS photo library.

## Sources

- [Immich v3.3.0 release notes](https://github.com/immich-app/immich/releases/tag/v3.3.0)
- [Immich v3.3.5 security release](https://github.com/immich-app/immich/releases/tag/v3.3.5)
- [Target release database version ranges](https://github.com/immich-app/immich/blob/v3.3.5/server/src/constants.ts)
- [Target release startup and migrations](https://github.com/immich-app/immich/blob/v3.3.5/server/src/services/database.service.ts)
- [Target release Compose configuration](https://github.com/immich-app/immich/blob/v3.3.5/docker/docker-compose.yml)
- [Hemera GitOps deployment process](flux-gitops.md)
