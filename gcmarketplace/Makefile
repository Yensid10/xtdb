# =============================================
# Project Variables
# =============================================

CHART_NAME := xtdb
APP_ID ?= $(CHART_NAME)

TRACK ?= 1.0.0
MARKETPLACE_TOOLS_TAG ?= 0.11.1

# Define image tags
XTDB_TAG ?= $(TRACK)
KAFKA_TAG ?= 31.3.1

# Define image sources
PROJECT_ID ?= $(shell gcloud config get-value project)
REGISTRY ?= us-central1-docker.pkg.dev/$(PROJECT_ID)/xtdb-repo
IMAGE_XTDB ?= $(REGISTRY)/xtdb:$(XTDB_TAG)
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
NAMESPACE ?= xtdb-deployment

# GKE and infrastructure configuration
VPC_NAME ?= xtdb-vpc
VPC_SUBNET_NAME ?= xtdb-vpc-public-subnet
VPC_SUBNET_IP ?= 10.10.10.0/24
VPC_SUBNET_REGION ?= us-central1
KUBERNETES_CLUSTER_NAME ?= xtdb-cluster
# KUBERNETES_CLUSTER_REGION ?= us-central1
KUBERNETES_CLUSTER_ZONE ?= us-central1
NODE_MACHINE_TYPE ?= n2-highmem-2
NODE_DISK_SIZE ?= 50
NODE_DISK_TYPE ?= pd-standard
NODE_COUNT ?= 1
EPHEMERAL_SSD_COUNT ?= 1

# Additional variables for deployment parameters
ifdef KAFKA_ENABLED
  KAFKA_ENABLED_FIELD = , "kafka.enabled": $(KAFKA_ENABLED)
endif

# Default deployment parameters
APP_PARAMETERS ?= { \
  "name": "xtdb-kubernetes-deployment", \
  "namespace": "$(NAMESPACE)", \
  "xtdb.serviceAccount": "xtdb-service-account", \
  "xtdbConfig.gcpProjectId": "$(PROJECT_ID)", \
  "xtdbConfig.gcpBucket": "$(PROJECT_ID)-xtdb-storage-bucket", \
  "xtdb.adminPassword": "auto-generate", \
  "xtdb.persistence.size": "50Gi", \
  "kafka.enabled": true, \
  "kafka.replicaCount": 3, \
  "kafka.persistence.size": "20Gi", \
  "kafka.zookeeper.replicaCount": 3, \
  "xtdbConfig.kafkaBootstrapServers": "kafka.$(NAMESPACE).svc.cluster.local:9092", \
  "xtdbConfig.kafkaLogTopic": "xtdb-log" \
}

# Build and deployment targets
.PHONY: setup-vpc setup-service-account setup-bucket setup-infra setup-namespace setup-workload-identity generate-tls build-xtdb-image build-deployer push-deployer update-deps deploy verify clean cleanup-deployment cleanup-infra cleanup-all setup-all

# =============================================
# Infrastructure Setup (in chronological order)
# =============================================

# 1. Setup VPC and subnet (first infrastructure component)
setup-vpc:
	@echo "Creating VPC and subnet..."
	gcloud compute networks create $(VPC_NAME) \
		--project=$(PROJECT_ID) \
		--subnet-mode=custom
	gcloud compute networks subnets create $(VPC_SUBNET_NAME) \
		--project=$(PROJECT_ID) \
		--network=$(VPC_NAME) \
		--region=$(VPC_SUBNET_REGION) \
		--range=$(VPC_SUBNET_IP)

# 2. Setup service account (needed for both GKE and storage)
setup-service-account:
	@echo "Creating service account..."
	gcloud iam service-accounts create xtdb-service-account \
		--project=$(PROJECT_ID) \
		--display-name="XTDB Service Account" || true
	gcloud projects add-iam-policy-binding $(PROJECT_ID) \
		--member="serviceAccount:xtdb-service-account@$(PROJECT_ID).iam.gserviceaccount.com" \
		--role="roles/storage.admin"

# 3. Setup GCS bucket (storage for XTDB)
setup-bucket:
	@echo "Creating GCS bucket..."
	gcloud storage buckets create gs://xtdb-storage-$(PROJECT_ID) \
		--project=$(PROJECT_ID) \
		--location=$(VPC_SUBNET_REGION) \
		--default-storage-class=STANDARD || true

# 4. Setup GKE cluster with advanced configuration
setup-infra: 
	@echo "Creating GKE cluster with Terraform-equivalent configuration..."
	gcloud container clusters create $(KUBERNETES_CLUSTER_NAME) \
		--project=$(PROJECT_ID) \
		--zone=$(KUBERNETES_CLUSTER_ZONE) \
		--network=$(VPC_NAME) \
		--subnetwork=$(VPC_SUBNET_NAME) \
		--num-nodes=$(NODE_COUNT) \
		--machine-type=$(NODE_MACHINE_TYPE) \
		--disk-size=$(NODE_DISK_SIZE) \
		--disk-type=$(NODE_DISK_TYPE) \
		--local-ssd-count=$(EPHEMERAL_SSD_COUNT) \
		--workload-pool=$(PROJECT_ID).svc.id.goog
	
	@echo "Creating application node pool..."
	gcloud container node-pools create application-pool \
		--cluster=$(KUBERNETES_CLUSTER_NAME) \
		--project=$(PROJECT_ID) \
		--zone=$(KUBERNETES_CLUSTER_ZONE) \
		--machine-type=$(NODE_MACHINE_TYPE) \
		--disk-size=$(NODE_DISK_SIZE) \
		--disk-type=$(NODE_DISK_TYPE) \
		--local-ssd-count=$(EPHEMERAL_SSD_COUNT) \
		--num-nodes=$(NODE_COUNT)
	
	@echo "Getting cluster credentials..."
	gcloud container clusters get-credentials $(KUBERNETES_CLUSTER_NAME) \
		--zone=$(KUBERNETES_CLUSTER_ZONE) \
		--project=$(PROJECT_ID)

# 5. Setup namespace and Kubernetes service account
setup-namespace:
	@echo "Creating namespace and Kubernetes service account..."
	kubectl create namespace $(NAMESPACE) || true
	kubectl create serviceaccount xtdb-service-account --namespace $(NAMESPACE) || true

# # 6. Setup workload identity (connects K8s SA to GCP SA)
# setup-workload-identity:
# 	@echo "Setting up workload identity..."
# 	gcloud iam service-accounts add-iam-policy-binding \
# 		xtdb-service-account@$(PROJECT_ID).iam.gserviceaccount.com \
# 		--role roles/iam.workloadIdentityUser \
# 		--member "serviceAccount:$(PROJECT_ID).svc.id.goog[$(NAMESPACE)/xtdb-service-account]"
# 	kubectl annotate serviceaccount xtdb-service-account \
# 		--namespace $(NAMESPACE) \
# 		iam.gke.io/gcp-service-account=xtdb-service-account@$(PROJECT_ID).iam.gserviceaccount.com \
# 		--overwrite

# =============================================
# Application Build and Deployment
# =============================================

# 7. Generate TLS certificates if needed
generate-tls:
	@echo "Generating TLS certificates..."
	# Add your TLS generation commands here if needed

# 8. Update Helm dependencies
update-deps:
	@echo "Updating Helm dependencies..."
	cd chart/xtdb && helm dependency update

# 9. Build the deployer image
build-deployer:
	@echo "Building deployer image..."
	docker build \
		--build-arg REGISTRY=$(REGISTRY) \
		--build-arg TAG=$(XTDB_TAG) \
		--build-arg MARKETPLACE_TOOLS_TAG=$(MARKETPLACE_TOOLS_TAG) \
		-t $(REGISTRY)/xtdb/deployer:$(XTDB_TAG) .

# 10. Push the deployer image
push-deployer: 
	@echo "Pushing deployer image..."
	docker push $(REGISTRY)/xtdb/deployer:$(XTDB_TAG)

# 11. Setup workload identity
workload-identity:	
	@echo "Setting up workload identity before deployment..."
	gcloud iam service-accounts add-iam-policy-binding \
		xtdb-service-account@$(PROJECT_ID).iam.gserviceaccount.com \
		--role roles/iam.workloadIdentityUser \
		--member "serviceAccount:$(PROJECT_ID).svc.id.goog[$(NAMESPACE)/xtdb-service-account]"

	@echo "Annotating service account..."
	kubectl annotate serviceaccount xtdb-service-account \
		--namespace $(NAMESPACE) \
		iam.gke.io/gcp-service-account=xtdb-service-account@$(PROJECT_ID).iam.gserviceaccount.com \
		--overwrite || true

# 12. Deploy to test environment
deploy:
	@echo "Deploying XTDB..."
	kubectl apply -f "https://raw.githubusercontent.com/GoogleCloudPlatform/marketplace-k8s-app-tools/master/crd/app-crd.yaml"
	mpdev install --deployer=$(REGISTRY)/xtdb/deployer:$(XTDB_TAG) \
		--parameters='$(APP_PARAMETERS)' 
	@echo "Waiting for 30 seconds to allow XTDB to initialise..."
	@sleep 30

# 13. Verify deployment
verify:
	@echo "Verifying XTDB deployment..."
	kubectl get pods -n $(NAMESPACE)
	kubectl get services -n $(NAMESPACE)
# @echo "XTDB should be accessible at:"
# @kubectl get service xtdb-service -n $(NAMESPACE) -o jsonpath="{.status.loadBalancer.ingress[0].ip}:{.spec.ports[0].port}" || echo "Service not available yet"

# =============================================
# Cleanup Operations (in reverse order)
# =============================================

# Clean up deployment
cleanup-deployment:
	@echo "Cleaning up deployment..."
	kubectl delete namespace $(NAMESPACE) || true

# Cleanup infrastructure (in reverse order of creation)
cleanup-infra:
	@echo "Cleaning up infrastructure..."
	gcloud container clusters delete $(KUBERNETES_CLUSTER_NAME) --zone=$(KUBERNETES_CLUSTER_ZONE) --quiet
	# Only try to delete node pool if cluster still exists (which it shouldn't)
	if gcloud container clusters describe $(KUBERNETES_CLUSTER_NAME) --zone=$(KUBERNETES_CLUSTER_ZONE) &>/dev/null; then \
		gcloud container node-pools delete application-pool --cluster=$(KUBERNETES_CLUSTER_NAME) --zone=$(KUBERNETES_CLUSTER_ZONE) --quiet; \
	fi
	gcloud storage rm -r gs://xtdb-storage-$(PROJECT_ID) || true
	gcloud iam service-accounts delete xtdb-service-account@$(PROJECT_ID).iam.gserviceaccount.com --quiet || true
	gcloud compute networks subnets delete $(VPC_SUBNET_NAME) --region=$(VPC_SUBNET_REGION) --quiet || true
	gcloud compute networks delete $(VPC_NAME) --quiet || true

# =============================================
# Complete Setup and Cleanup
# =============================================

# Setup initial infrastructure
setup-initial: setup-vpc setup-service-account setup-bucket setup-infra

# Setup deployment (infrastructure + deployment)
setup-deployment: setup-namespace generate-tls update-deps build-deployer push-deployer workload-identity deploy verify

# Complete setup (infrastructure + deployment) in chronological order
setup-all: setup-initial setup-deployment

# Reboot deployment
reboot-deployment: cleanup-deployment setup-deployment

# Complete cleanup (in reverse order)
cleanup-all: cleanup-deployment cleanup-infra
