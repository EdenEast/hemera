#!/usr/bin/env bash

# Shared Cluster Node inventory for Initial Setup scripts.
# TODO_CONFIRM: update these placeholder LAN addresses after network planning.

CLUSTER_NODES=(k8s-cp-01 k8s-worker-01 k8s-worker-02)

cluster_node_ip() {
  case "${1:-}" in
  k8s-cp-01) echo "192.168.1.50" ;;
  k8s-worker-01) echo "192.168.1.51" ;;
  k8s-worker-02) echo "192.168.1.52" ;;
  *) return 1 ;;
  esac
}

cluster_node_role() {
  case "${1:-}" in
  k8s-cp-01) echo "control-plane" ;;
  k8s-worker-01 | k8s-worker-02) echo "worker" ;;
  *) return 1 ;;
  esac
}

cluster_node_target() {
  local node="${1:-}"
  local user="${HEMERA_DEPLOY_USER:-root}"
  local ip

  ip="$(cluster_node_ip "$node")" || return 1
  echo "$user@$ip"
}

require_cluster_node() {
  local node="${1:-}"
  if ! cluster_node_ip "$node" >/dev/null; then
    echo "unknown Cluster Node: $node" >&2
    echo "known Cluster Nodes: ${CLUSTER_NODES[*]}" >&2
    return 1
  fi
}
