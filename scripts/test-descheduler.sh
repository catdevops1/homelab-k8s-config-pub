#!/bin/bash
# Test descheduler deployment

set -e

echo "🧪 Testing Descheduler Deployment"
echo ""

# Check if descheduler is running
echo "1. Checking CronJob..."
kubectl get cronjob -n kube-system descheduler

echo ""
echo "2. Checking recent jobs..."
kubectl get jobs -n kube-system -l app=descheduler --sort-by=.metadata.creationTimestamp | tail -5

echo ""
echo "3. Creating manual test job..."
kubectl create job descheduler-test -n kube-system --from=cronjob/descheduler

echo ""
echo "4. Waiting for job to complete..."
sleep 10

echo ""
echo "5. Checking logs..."
kubectl logs -n kube-system -l job-name=descheduler-test --tail=30

echo ""
echo "6. Pod distribution across nodes:"
kubectl get pods -A -o wide | awk '{print $8}' | sort | uniq -c

echo ""
echo "✅ Test complete!"
