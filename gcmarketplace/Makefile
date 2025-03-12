# Include common makefiles (you may need to create or copy these from the PostgreSQL project)

# If you don't have these files, you can start without them and add later
# include ../crd.Makefile
# include ../gcloud.Makefile
# include ../var.Makefile
# include ../images.Makefile

CHART_NAME := xtdb
APP_ID ?= $(CHART_NAME)

TRACK ?= 1.0.0
SERVICE_NAME := services/your-service-id.cloudpartnerservices.goog

# Define image tags
XTDB_TAG ?= $(TRACK)
KAFKA_TAG ?= 31.3.1

# Define image sources
PROJECT_ID ?= bcs-test-450214
REGISTRY ?= us-central1-docker.pkg.dev/$(PROJECT_ID)/quickstart-docker-repo
IMAGE_XTDB ?= $(REGISTRY)/xtdb-image:$(XTDB_TAG)
IMAGE_KAFKA ?= docker.io/bitnami/kafka:$(KAFKA_TAG)

# Main image
image-$(CHART_NAME) := $(IMAGE_XTDB)

# List of images used in application
ADDITIONAL_IMAGES := kafka

# Additional images variable names should correspond with ADDITIONAL_IMAGES list
image-kafka := $(IMAGE_KAFKA)

# Build ID and release info
BUILD_ID := $(shell date --utc +%Y%m%d-%H%M%S)
RELEASE ?= $(XTDB_TAG)-$(BUILD_ID)
NAME ?= $(APP_ID)-1

# Deployment namespace
NAMESPACE ?= test-deployment

# Additional variables for deployment parameters
ifdef KAFKA_ENABLED
  KAFKA_ENABLED_FIELD = , "kafka.enabled": $(KAFKA_ENABLED)
endif

ifdef TLS_ENABLED
  TLS_ENABLED_FIELD = , "tls.enabled": $(TLS_ENABLED)
endif

# Default deployment parameters
APP_PARAMETERS ?= { \
  "name": "$(NAME)", \
  "namespace": "$(NAMESPACE)", \
  "xtdb.serviceAccount": "xtdb-service-account", \
  "gcpProjectId": "$(PROJECT_ID)", \
  "gcpBucket": "xtdb-storage-bucket" \
  $(KAFKA_ENABLED_FIELD) \
  $(TLS_ENABLED_FIELD) \
}

# Build and deployment targets
.PHONY: build-deployer push-deployer deploy clean

# Build the deployer image
build-deployer:
	docker build -f deployer.dockerfile \
		--build-arg REGISTRY=$(REGISTRY) \
		--build-arg TAG=$(XTDB_TAG) \
		-t $(REGISTRY)/$(APP_ID)/deployer:$(XTDB_TAG) .

# Push the deployer image
push-deployer: build-deployer
	docker push $(REGISTRY)/$(APP_ID)/deployer:$(XTDB_TAG)

# Update Helm dependencies
update-deps:
	cd chart && helm dependency update

# Deploy to test environment
deploy: push-deployer update-deps
	kubectl apply -f "https://raw.githubusercontent.com/GoogleCloudPlatform/marketplace-k8s-app-tools/master/crd/app-crd.yaml"
	mpdev install --deployer=$(REGISTRY)/$(APP_ID)/deployer:$(XTDB_TAG) \
		--parameters='$(APP_PARAMETERS)'

# Clean up test deployment
clean:
	kubectl delete namespace $(NAMESPACE) || true

# Generate TLS certificate
generate-tls:
	mkdir -p chart/files
	openssl req -x509 -newkey rsa:4096 -keyout key.pem -out cert.pem -days 365 -nodes -subj "/CN=xtdb"
	openssl pkcs12 -export -out chart/files/keystore.p12 -inkey key.pem -in cert.pem -password pass:changeme

# Setup test environment
setup-test:
	gcloud container clusters create marketplace-test-cluster --region=us-central1 --num-nodes=1 --machine-type=e2-standard-4 --disk-type=pd-standard --disk-size=100 --project=$(PROJECT_ID)
	gcloud container clusters get-credentials marketplace-test-cluster --region=us-central1
	kubectl create namespace $(NAMESPACE)
	kubectl create serviceaccount xtdb-service-account --namespace $(NAMESPACE)
	gcloud iam service-accounts create xtdb-service-account --display-name="XTDB Service Account" --project=$(PROJECT_ID) || true
	gcloud projects add-iam-policy-binding $(PROJECT_ID) --member="serviceAccount:xtdb-service-account@$(PROJECT_ID).iam.gserviceaccount.com" --role="roles/storage.admin"
	gcloud iam service-accounts add-iam-policy-binding xtdb-service-account@$(PROJECT_ID).iam.gserviceaccount.com --role roles/iam.workloadIdentityUser --member "serviceAccount:$(PROJECT_ID).svc.id.goog[$(NAMESPACE)/xtdb-service-account]"
	kubectl annotate serviceaccount xtdb-service-account --namespace $(NAMESPACE) iam.gke.io/gcp-service-account=xtdb-service-account@$(PROJECT_ID).iam.gserviceaccount.com
	gcloud storage buckets create gs://xtdb-storage-bucket --location=us-central1 || true

# Cleanup test environment
cleanup-test:
	kubectl delete namespace $(NAMESPACE) || true
	gcloud container clusters delete marketplace-test-cluster --region=us-central1 --quiet
	gcloud storage rm -r gs://xtdb-storage-bucket || true
