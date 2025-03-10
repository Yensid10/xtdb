FROM gcr.io/cloud-marketplace-tools/k8s/deployer_helm:0.11.1

COPY chart /data/chart
COPY schema.yaml /data/
COPY application.yaml /data-test/

ARG REGISTRY
ARG TAG

ENV REGISTRY=$REGISTRY
ENV TAG=$TAG

# Provide registry prefix and tag for default values for images
RUN cat /data/chart/values.yaml \
    | sed "s|repository: .*|repository: ${REGISTRY}/xtdb-image|g" \
    | sed "s|tag: .*|tag: ${TAG}|g" \
    > /data/chart/values.yaml.new \
    && mv /data/chart/values.yaml.new /data/chart/values.yaml
