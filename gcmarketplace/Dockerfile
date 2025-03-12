ARG MARKETPLACE_TOOLS_TAG
FROM marketplace.gcr.io/google/c2d-debian11 AS build

RUN apt-get update \
    && apt-get install -y --no-install-recommends gettext

# Copy your XTDB chart
ADD chart /tmp/chart
RUN cd /tmp && tar -czvf /tmp/xtdb.tar.gz chart

# If you have test charts, uncomment and adapt these lines
# ADD apptest/deployer/xtdb /tmp/test/chart
# RUN cd /tmp/test \
#     && tar -czvf /tmp/test/xtdb.tar.gz chart/

# Copy schema.yaml
ADD schema.yaml /tmp/schema.yaml

ARG REGISTRY
ARG TAG

# Replace variables in schema.yaml
RUN cat /tmp/schema.yaml \
    | env -i "REGISTRY=$REGISTRY" "TAG=$TAG" envsubst \
    > /tmp/schema.yaml.new \
    && mv /tmp/schema.yaml.new /tmp/schema.yaml

# If you have test schema, uncomment and adapt these lines
# ADD apptest/deployer/schema.yaml /tmp/apptest/schema.yaml
# RUN cat /tmp/apptest/schema.yaml \
#     | env -i "REGISTRY=$REGISTRY" "TAG=$TAG" envsubst \
#     > /tmp/apptest/schema.yaml.new \
#     && mv /tmp/apptest/schema.yaml.new /tmp/apptest/schema.yaml

# Copy application.yaml if you have one
# ADD application.yaml /tmp/application.yaml
# RUN cat /tmp/application.yaml \
#     | env -i "REGISTRY=$REGISTRY" "TAG=$TAG" envsubst \
#     > /tmp/application.yaml.new \
#     && mv /tmp/application.yaml.new /tmp/application.yaml

FROM gcr.io/cloud-marketplace-tools/k8s/deployer_helm:$MARKETPLACE_TOOLS_TAG
COPY --from=build /tmp/xtdb.tar.gz /data/chart/
# If you have test charts, uncomment this line
# COPY --from=build /tmp/test/xtdb.tar.gz /data-test/chart/
# COPY --from=build /tmp/apptest/schema.yaml /data-test/
COPY --from=build /tmp/schema.yaml /data/
# COPY --from=build /tmp/application.yaml /data-test/
