#!/bin/bash
# Label nodes by power reliability and workload type

set -e

echo "🏷️  Node Labeling Script"
echo ""
echo "This script helps you label nodes for descheduler affinity."
echo ""

# Function to label a node
label_node() {
    local node=$1
    local reliability=$2
    local workload=$3
    local availability=$4
    
    echo "Labeling node: $node"
    kubectl label nodes "$node" \
        power-reliability="$reliability" \
        workload-type="$workload" \
        availability="$availability" \
        --overwrite
}

# Example: Customize these for your cluster
echo "Example labels:"
echo "  label_node \"control-plane\" \"ups-backed\" \"critical\" \"high\""
echo "  label_node \"worker-node-1\" \"ups-backed\" \"general\" \"high\""
echo "  label_node \"unstable-node\" \"intermittent\" \"stateless-only\" \"low\""
echo ""
echo "Modify this script with your actual node names!"

# Uncomment and customize these lines for your cluster:
# label_node "control-plane" "ups-backed" "critical" "high"
# label_node "worker-1" "ups-backed" "general" "high"
# label_node "worker-2" "intermittent" "stateless-only" "low"

echo ""
echo "✅ Done! Verify with:"
echo "kubectl get nodes -L power-reliability,workload-type,availability"
