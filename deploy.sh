#!/bin/bash
set -e

echo " Running Terraform..."
cd terraform
terraform init
terraform apply -auto-approve
cd ..
echo "Waiting 30 seconds for SSH to become available..."
sleep 30

echo " Extracting Ansible inventory..."
terraform -chdir=terraform output -raw ansible_inventory > ansible/inventory/hosts.ini
terraform -chdir=terraform output -raw ansible_inventory > ansible/inventory/hosts.ini && echo "" >> ansible/inventory/hosts.ini
echo " Parsing leader node IP (db1) from inventory..."
DB1_IP=$(awk '/^db1 / { for (i=1; i<=NF; i++) if ($i ~ /^ansible_host=/) { split($i,a,"="); print a[2] } }' ansible/inventory/hosts.ini)

if [ -z "$DB1_IP" ]; then
  echo " Failed to extract db1 IP"
  exit 1
fi

echo "db1 public IP: $DB1_IP"

echo " Running Ansible to setup etcd and Patroni cluster..."
cd ansible
ansible-playbook -i inventory/hosts.ini site.yml
cd ..

echo " Waiting for Patroni cluster to be ready..."
sleep 30  # Optional: Adjust if needed or add curl health check here

echo " Writing .env file for app..."
{
  echo "DB_HOST=$DB1_IP"
  echo "DB_PORT=5432"
  echo "DB_USER=postgres"
  echo "DB_PASSWORD=postgres"
  echo "DB_NAME=shubhamdb"
} > app/.env

echo " Building and starting FastAPI app with Docker Compose..."
docker compose down --remove-orphans
docker compose up --build -d

echo " Cluster status via patronictl list on db1:"
ssh -o StrictHostKeyChecking=no -i ~/.ssh/shubham-key ubuntu@$DB1_IP \
  "patronictl -c /etc/patroni/postgres.yml list || echo 'Failed to connect or list cluster'"

echo " Done! App should be available at http://localhost:8000"
