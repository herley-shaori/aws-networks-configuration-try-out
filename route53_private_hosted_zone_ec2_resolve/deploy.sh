#!/usr/bin/env bash
set -euo pipefail

terraform init
terraform apply -auto-approve
