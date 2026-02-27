#!/usr/bin/env bash
# generate-certs.sh — macOS mTLS Certificate Generator for Confluent Kafka
set -euo pipefail

# ── Config ──────────────────────────────────────────────
OPENSSL="$(brew --prefix openssl@3)/bin/openssl"
CERTS_DIR="${1:-$HOME/Confluent-kafka/certs}"
CA_PASS="kafka-ca-password"
STORE_PASS="kafka-broker-password"
CA_VALIDITY=3650
CERT_VALIDITY=365
KEY_SIZE=4096

mkdir -p $CERTS_DIR && cd $CERTS_DIR
echo "🔐 Generating mTLS certificates in $CERTS_DIR"
# ── Step 1: Certificate Authority ───────────────────────
echo "[1/6] Generating CA..."
$OPENSSL genrsa -aes256 -passout pass:$CA_PASS \
  -out ca.key $KEY_SIZE
$OPENSSL req -new -x509 -key ca.key -passin pass:$CA_PASS \
  -out ca.crt -days $CA_VALIDITY \
  -subj "/C=US/ST=CA/O=MyOrg/CN=KafkaCA"
echo "  ✓ ca.crt created"

# ── Step 2: Broker Certificate ──────────────────────────
echo "[2/6] Generating Broker cert..."
$OPENSSL genrsa -out broker.key $KEY_SIZE
$OPENSSL req -new -key broker.key -out broker.csr \
  -subj "/CN=kafka-broker/O=MyOrg"
cat > /tmp/broker-san.cnf <<EOF
[req_ext]
subjectAltName=DNS:kafka,DNS:localhost,IP:127.0.0.1
EOF
$OPENSSL x509 -req -in broker.csr -CA ca.crt \
  -CAkey ca.key -passin pass:$CA_PASS \
  -CAcreateserial -out broker.crt -days $CERT_VALIDITY \
  -extfile /tmp/broker-san.cnf -extensions req_ext
echo "  ✓ broker.crt created"

# ── Step 3: Client Certificate ──────────────────────────
echo "[3/6] Generating Client cert..."
$OPENSSL genrsa -out client.key $KEY_SIZE
$OPENSSL req -new -key client.key -out client.csr \
  -subj "/CN=kafka-client/O=MyOrg"
$OPENSSL x509 -req -in client.csr -CA ca.crt \
  -CAkey ca.key -passin pass:$CA_PASS \
  -CAcreateserial -out client.crt -days $CERT_VALIDITY
echo "  ✓ client.crt created"

# ── Step 4: Broker PKCS12 → JKS Keystore ───────────────
echo "[4/6] Building kafka.keystore.jks..."
$OPENSSL pkcs12 -export -in broker.crt -inkey broker.key \
  -chain -CAfile ca.crt -name kafka-broker \
  -out broker.p12 -passout pass:$STORE_PASS
keytool -importkeystore -noprompt \
  -srckeystore broker.p12 -srcstoretype PKCS12 \
  -srcstorepass $STORE_PASS \
  -destkeystore kafka.keystore.jks \
  -deststorepass $STORE_PASS -destkeypass $STORE_PASS
echo "  ✓ kafka.keystore.jks created"

# ── Step 5: Truststore (CA → JKS) ──────────────────────
echo "[5/6] Building kafka.truststore.jks..."
keytool -import -trustcacerts -noprompt \
  -alias ca-root -file ca.crt \
  -keystore kafka.truststore.jks \
  -storepass $STORE_PASS
echo "  ✓ kafka.truststore.jks created"

# ── Step 6: Credential files for Kafka ──────────────────
echo "[6/6] Writing credential files..."
echo "$STORE_PASS" > keystore_creds
echo "$STORE_PASS" > truststore_creds
rm -f broker.csr client.csr broker.p12 ca.srl

echo ""
echo "✅ Done! Files in $CERTS_DIR:"
ls -lh *.crt *.key *.jks keystore_creds truststore_creds
