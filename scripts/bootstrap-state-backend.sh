#!/bin/bash
#
# State Backend Bootstrap Script
# Creates OCI Object Storage bucket and Autonomous Database for Terraform state locking
#
# Prerequisites:
#   - OCI CLI configured with appropriate permissions
#   - Compartment OCID where resources will be created
#   - User has permissions to create buckets and Autonomous Databases
#
# Usage:
#   ./bootstrap-state-backend.sh <compartment_ocid> <bucket_name> <namespace> <region> [lock_table_name]
#
# Example:
#   ./bootstrap-state-backend.sh ocid1.compartment.oc1..xxxxx terraform-state mynamespace us-ashburn-1 terraform_locks

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Check arguments
if [ $# -lt 4 ]; then
    log_error "Usage: $0 <compartment_ocid> <bucket_name> <namespace> <region> [lock_table_name]"
    exit 1
fi

COMPARTMENT_OCID=$1
BUCKET_NAME=$2
NAMESPACE=$3
REGION=$4
LOCK_TABLE_NAME=${5:-terraform_locks}

log_info "Starting state backend bootstrap..."
log_info "Compartment: $COMPARTMENT_OCID"
log_info "Bucket: $BUCKET_NAME"
log_info "Namespace: $NAMESPACE"
log_info "Region: $REGION"
log_info "Lock Table: $LOCK_TABLE_NAME"

# Verify OCI CLI is available
if ! command -v oci &> /dev/null; then
    log_error "OCI CLI not found. Please install: https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm"
    exit 1
fi

# Verify authentication
log_info "Verifying OCI authentication..."
if ! oci iam user get --user-id "$(oci iam user list --compartment-id "$COMPARTMENT_OCID" --query "data[0].id" --raw-output)" >/dev/null 2>&1; then
    log_error "OCI authentication failed. Run 'oci setup config' first."
    exit 1
fi

# 1. Create Object Storage Bucket
log_info "Creating Object Storage bucket: $BUCKET_NAME"

if oci os bucket create --name "$BUCKET_NAME" --compartment-id "$COMPARTMENT_OCID" --region "$REGION" --versioning Enabled --public-access-type NoPublicAccess >/dev/null 2>&1; then
    log_info "Bucket created successfully"
else
    # Check if bucket already exists
    if oci os bucket get --name "$BUCKET_NAME" --namespace "$NAMESPACE" --region "$REGION" >/dev/null 2>&1; then
        log_warn "Bucket already exists, enabling versioning..."
        oci os bucket update --name "$BUCKET_NAME" --namespace "$NAMESPACE" --region "$REGION" --versioning Enabled >/dev/null
        log_info "Versioning enabled on existing bucket"
    else
        log_error "Failed to create bucket"
        exit 1
    fi
fi

# 2. Enable Bucket Encryption (OCI-managed keys)
log_info "Enabling bucket encryption..."
oci os bucket update --name "$BUCKET_NAME" --namespace "$NAMESPACE" --region "$REGION" --encryption '{"encryptionAlgorithm": "AES256"}' >/dev/null 2>&1 || log_warn "Could not enable encryption (may already be enabled)"

# 3. Create Lifecycle Policy (delete old versions after 90 days)
log_info "Creating lifecycle policy..."
cat > /tmp/lifecycle-policy.json <<EOF
{
  "rules": [
    {
      "name": "delete-old-versions",
      "action": "DELETE",
      "objectNameFilter": {"inclusionPrefixes": [], "exclusionPrefixes": []},
      "timeAmount": 90,
      "timeUnit": "DAYS",
      "isEnabled": true,
      "objectVersionFilter": {"isCurrentVersion": false}
    }
  ]
}
EOF

oci os bucket lifecycle-policy put --name "$BUCKET_NAME" --namespace "$NAMESPACE" --region "$REGION" --file /tmp/lifecycle-policy.json >/dev/null 2>&1 || log_warn "Could not create lifecycle policy"
rm -f /tmp/lifecycle-policy.json

# 4. Create Autonomous Database for State Locking
log_info "Creating Autonomous Database for state locking..."

# Generate a random admin password for the ADB
ADMIN_PASSWORD=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)

# Create ATP database (Always Free tier eligible)
log_info "Creating Autonomous Transaction Processing database..."
ADB_RESPONSE=$(oci db autonomous-database create \
    --compartment-id "$COMPARTMENT_OCID" \
    --display-name "terraform-state-locking" \
    --db-name "TFSTATE" \
    --admin-password "$ADMIN_PASSWORD" \
    --cpu-core-count 1 \
    --data-storage-size-in-tbs 1 \
    --is-free-tier true \
    --license-model LICENSE_INCLUDED \
    --is-auto-scaling-enabled false \
    --region "$REGION" \
    --wait-for-state AVAILABLE \
    --query "data.id" --raw-output 2>/dev/null)

if [ -z "$ADB_RESPONSE" ]; then
    log_error "Failed to create Autonomous Database"
    exit 1
fi

ADB_OCID=$ADB_RESPONSE
log_info "Autonomous Database created: $ADB_OCID"

# 5. Create Lock Table in ADB
log_info "Waiting for database to be ready..."
sleep 30

# Get wallet for database connection
log_info "Generating database wallet..."
oci db autonomous-database generate-wallet \
    --autonomous-database-id "$ADB_OCID" \
    --password "$ADMIN_PASSWORD" \
    --file /tmp/wallet.zip >/dev/null 2>&1

# Extract wallet
unzip -q /tmp/wallet.zip -d /tmp/wallet
DB_CONNECTION_STRING=$(grep -r "TCPS" /tmp/wallet/tnsnames.ora | head -1 | sed 's/.*= //' | tr -d ')')

# Create lock table using SQL*Plus or Python
log_info "Creating lock table..."
cat > /tmp/create_lock_table.sql <<EOF
CREATE TABLE ${LOCK_TABLE_NAME} (
    lock_id VARCHAR2(128) PRIMARY KEY,
    lock_owner VARCHAR2(256),
    lock_created TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    lock_expires TIMESTAMP,
    lock_data CLOB
);
CREATE INDEX idx_lock_expires ON ${LOCK_TABLE_NAME}(lock_expires);
EXIT;
EOF

# Note: In production, you'd use a proper SQL client
# This is a placeholder - actual table creation requires database client setup
log_warn "Lock table creation requires database client. Run manually:"
log_warn "  sqlplus admin/${ADMIN_PASSWORD}@${DB_CONNECTION_STRING} @/tmp/create_lock_table.sql"

# 6. Output Configuration
log_info "State backend bootstrap complete!"
echo ""
echo "=========================================="
echo "BACKEND CONFIGURATION"
echo "=========================================="
cat <<EOF

# Add to backend.hcl or use with terraform init:
bucket_name     = "${BUCKET_NAME}"
namespace       = "${NAMESPACE}"
region          = "${REGION}"
object_name     = "terraform.tfstate"

# State Locking (Autonomous Database)
lock_table_name = "${LOCK_TABLE_NAME}"
lock_table_ocid = "${ADB_OCID}"

# Database Connection (for manual lock table creation)
DB_ADMIN_PASSWORD = "${ADMIN_PASSWORD}"
DB_CONNECTION_STRING = "${DB_CONNECTION_STRING}"

# Save these values securely!
EOF

# Cleanup
rm -f /tmp/wallet.zip
rm -rf /tmp/wallet
rm -f /tmp/create_lock_table.sql

log_info "Bootstrap complete. Save the above configuration!"