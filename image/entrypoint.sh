#!/bin/sh
# Assemble conf/sync.properties from the ConfigMap, the Secret and the run-mode env, then start the tool.
set -eu
cd /opt/starrocks-cluster-sync
{
  cat /config/sync.properties
  echo
  if [ -f /secrets/credentials.properties ]; then
    cat /secrets/credentials.properties
    echo
  fi
  if [ -n "${ONE_TIME_RUN_MODE:-}" ]; then
    echo "one_time_run_mode=${ONE_TIME_RUN_MODE}"
  fi
} > conf/sync.properties
exec ./bin/start.sh
