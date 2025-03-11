FROM gcr.io/cloud-marketplace-tools/k8s/deployer_helm:0.11.1

COPY chart /data/chart
COPY schema.yaml /data/
COPY application.yaml /data-test/

ARG REGISTRY
ARG TAG

ENV REGISTRY=$REGISTRY
ENV TAG=$TAG

# Update the values.yaml file with the registry and tag
RUN sed -i "s|repository:.*|repository: ${REGISTRY}|g" /data/chart/values.yaml && \
    sed -i "s|tag:.*|tag: ${TAG}|g" /data/chart/values.yaml