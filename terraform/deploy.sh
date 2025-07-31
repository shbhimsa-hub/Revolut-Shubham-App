#!/bin/bash
set -e

echo "🚀 Running Terraform..."
terraform init
terraform apply -auto-approve

echo "📥 Extracting Ansible inventory..."
terraform output -raw ansible_inventory > ../ansible/inventory/hosts.ini
cd ..

echo "📡 Parsing leader node IP (db1) from inventory..."
DB1_IP=$(awk '/^db1 / { for (i=1; i<=NF; i++) if ($i ~ /^ansible_host=/) { split($i,a,"="); print a[2] } }' ansible/inventory/hosts.ini)
DB1_IP=$(awk '/^db1 / { for (i=1; i<=NF; i++) if ($i ~ /^ansible_host=/) { split($i,a,"="); print a[2] } }' ../ansible/inventory/hosts.ini)
if [ -z "$DB1_IP" ]; then
  echo "❌ Failed to extract db1 IP"
  exit 1
fi

echo "✅ db1 public IP: $DB1_IP"

echo "🔐 Writing .env file for app..."
cat > app/.env <<EOF
DB_HOST=$DB1_IP
DB_PORT=5432
DB_USER=postgres
DB_PASSWORD=postgres
DB_NAME=postgres
EOF


echo "🔧 Running Ansible to setup etcd and Patroni cluster..."
cd ansible
ansible-playbook -i inventory/hosts.ini site.yml
cd ..

echo "🐳 Building and starting FastAPI app with Docker Compose..."
docker compose down --remove-orphans
docker compose up --build -d

echo "✅ Done! App should be available at http://localhost:8000"
