#!/bin/bash

# Generate a random password for the keystore
KEYSTORE_PASSWORD=$(openssl rand -base64 16)

# Generate private key and certificate
openssl req -x509 -newkey rsa:4096 -keyout xtdb.key -out xtdb.crt -days 365 -nodes -subj "/CN=xtdb"

# Convert to PKCS12 format
openssl pkcs12 -export -in xtdb.crt -inkey xtdb.key -out xtdb.p12 -name xtdb -password pass:$KEYSTORE_PASSWORD

# Convert to JKS format
keytool -importkeystore -srckeystore xtdb.p12 -srcstoretype PKCS12 -srcstorepass $KEYSTORE_PASSWORD -destkeystore xtdb.jks -deststoretype JKS -deststorepass $KEYSTORE_PASSWORD

# Create a new ssl_config.yaml with the generated password
cat > ssl_config.yaml << EOF
server:
  port: 5432
  ssl:
    keyStore: /ssl/xtdb.jks
    keyStorePassword: $KEYSTORE_PASSWORD

log: !Local
  path: "/var/lib/xtdb/log"

storage: !Local
  path: "/var/lib/xtdb/buffers"

healthz:
  port: 8080

modules: 
- !HttpServer
  port: 3000
EOF

echo "SSL certificates and configuration generated successfully!"
echo "Keystore password: $KEYSTORE_PASSWORD" 