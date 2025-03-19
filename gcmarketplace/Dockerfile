ARG MARKETPLACE_TOOLS_TAG=latest
FROM marketplace.gcr.io/google/c2d-debian11 AS build

RUN apt-get update \
    && apt-get install -y --no-install-recommends gettext

# Add your chart files
ADD chart/xtdb /tmp/chart
RUN cd /tmp && tar -czvf /tmp/xtdb.tar.gz chart

# Add your schema file and verify it exists
ADD schema.yaml /tmp/schema.yaml
RUN cat /tmp/schema.yaml && echo "Schema file exists and is readable"

# If you have test files
# ADD apptest/deployer/xtdb /tmp/test/chart
# RUN cd /tmp/test && tar -czvf /tmp/test/xtdb.tar.gz chart/
# ADD apptest/deployer/schema.yaml /tmp/apptest/schema.yaml

ARG REGISTRY
ARG TAG

# No need to use envsubst to replace variables here anymore as registry is handled by marketplace
# RUN cat /tmp/schema.yaml \
#     | env -i "REGISTRY=$REGISTRY" "TAG=$TAG" envsubst \
#     > /tmp/schema.yaml.new \
#     && mv /tmp/schema.yaml.new /tmp/schema.yaml

# Final image
FROM gcr.io/cloud-marketplace-tools/k8s/deployer_helm:$MARKETPLACE_TOOLS_TAG
COPY --from=build /tmp/xtdb.tar.gz /data/chart/
COPY --from=build /tmp/schema.yaml /data/
RUN cat /data/schema.yaml && echo "Schema file copied successfully to final image"
# COPY --from=build /tmp/test/xtdb.tar.gz /data-test/chart/
# COPY --from=build /tmp/apptest/schema.yaml /data-test/
