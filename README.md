# StarRocks Cluster Sync on Kubernetes

Runs the [StarRocks Cluster Sync](https://docs.starrocks.io/docs/administration/data_migration_tool/) tool on Kubernetes, either continuously (Deployment) or as a single catch-up pass (Job / CronJob).

```
image/   Dockerfile + entrypoint (downloads the official tarball at build time)
k8s/     namespace, ConfigMap, Secret, Deployment, Job, CronJob
```

## 1. Build the image

```bash
docker build -t starrocks-cluster-sync:2.0 image/
# air-gapped: put the tarball next to the Dockerfile and point at it
docker build --build-arg SYNC_TGZ=starrocks-cluster-sync.tar.gz -t starrocks-cluster-sync:2.0 image/
# kind
kind load docker-image starrocks-cluster-sync:2.0 --name <cluster>
```

## 2. Configure

Edit `k8s/10-configmap.yaml`: set `source_fe_host`, `target_fe_host`, ports, users, and `include_data_list` / `exclude_data_list`.

Get the source cluster token from any source FE:

```bash
kubectl -n <source-ns> exec <source-fe-pod> -- grep ^token= /opt/starrocks/fe/meta/image/VERSION
```

Create the credentials Secret (do not commit real values; `k8s/20-secret.yaml` is a placeholder):

```bash
kubectl apply -f k8s/00-namespace.yaml
kubectl -n sync create secret generic starrocks-cluster-sync-credentials \
  --from-literal=credentials.properties="source_cluster_token=<token>
source_cluster_password=<pw>
target_cluster_password=<pw>"
kubectl apply -f k8s/10-configmap.yaml
```

Keys in the Secret override keys in the ConfigMap. `ONE_TIME_RUN_MODE` in the pod env overrides `one_time_run_mode` in both.

## 3a. Continuous (Deployment)

```bash
kubectl apply -f k8s/30-deployment.yaml
kubectl -n sync logs -f deploy/starrocks-cluster-sync
```

## 3b. One-time (Job)

```bash
kubectl apply -f k8s/31-job.yaml
kubectl -n sync wait --for=condition=complete job/starrocks-cluster-sync --timeout=1h
kubectl -n sync logs job/starrocks-cluster-sync | tail -20
kubectl -n sync delete job starrocks-cluster-sync
```

Exit 0: every table synced. Exit 1: some tables hold a partition that cannot be reproduced on the target; the log names them.
The pod exits on the next report tick after the last table finishes, so `report_interval_seconds` (default here 60) bounds the extra wait.

## 3c. Scheduled (CronJob)

```bash
kubectl apply -f k8s/32-cronjob.yaml          # every 6 h, edit spec.schedule
kubectl -n sync create job --from=cronjob/starrocks-cluster-sync manual-$(date +%s)   # run now
```

## Verify

```bash
kubectl -n sync logs deploy/starrocks-cluster-sync | grep -E 'Sync table progress|All tables have been synchronized'
```

Replication jobs are listed on the target cluster: `SHOW PROC '/replications';`

## Shared-data target

Disable compaction on the target for the tables being synced, keep it on for everything else:

```sql
SELECT TABLE_NAME, TABLE_ID FROM information_schema.tables_config WHERE TABLE_SCHEMA='<db>';
ADMIN SET FRONTEND CONFIG ('lake_compaction_disable_ids' = '<id1>;<id2>');
```

The setting is runtime-only. Add `lake_compaction_disable_ids = ...` to the target FE config to survive restarts.

## Change config

```bash
kubectl apply -f k8s/10-configmap.yaml
kubectl -n sync rollout restart deploy/starrocks-cluster-sync   # Deployment mode; a Job picks it up on next run
```

## Remove

```bash
kubectl delete -f k8s/
```
