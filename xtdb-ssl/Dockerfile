FROM ghcr.io/xtdb/xtdb:latest

# Install OpenSSL and keytool (JDK)
RUN apt-get update && apt-get install -y \
    openssl \
    default-jdk \
    && rm -rf /var/lib/apt/lists/*

# Create directories
RUN mkdir -p /ssl /scripts

# Copy the certificate generation script
COPY generate-certs.sh /scripts/
RUN chmod +x /scripts/generate-certs.sh

# Create an entrypoint script
RUN echo '#!/bin/bash\n\
# Generate fresh certs\n\
cd /ssl\n\
/scripts/generate-certs.sh\n\
\n\
# Start XTDB with the generated config\n\
exec java $JDK_JAVA_OPTIONS \
    -Dclojure.main.report=stderr \
    --add-opens=java.base/java.nio=ALL-UNNAMED \
    -Dio.netty.tryReflectionSetAccessible=true \
    -cp /usr/local/lib/xtdb/xtdb-standalone.jar \
    clojure.main -m xtdb.main -f /ssl/ssl_config.yaml\n\
' > /scripts/entrypoint.sh && chmod +x /scripts/entrypoint.sh

WORKDIR /ssl
VOLUME /ssl

# Expose ports
EXPOSE 5432 8080 3000

ENTRYPOINT ["/scripts/entrypoint.sh"] 