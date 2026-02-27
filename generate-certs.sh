#!/usr/bin/env bash
# generate-certs.sh — macOS mTLS Certificate Generator for Confluent Kafka
set -euo pipefail

# ── Config ──────────────────────────────────────────────
OPENSSL="$(brew --prefix openssl@3)/bin/openssl"
CERTS_DIR="${1:-$HOME/kafka-mtls/certs}"
CA_PASS="kafka-ca-password"
STORE_PASS="kafka-broker-password"
CA_VALIDITY=3650
CERT_VALIDITY=365
KEY_SIZE=4096

mkdir -p $CERTS_DIR && cd $CERTS_DIR
echo "🔐 Generating mTLS certificates in $CERTS_DIR"
