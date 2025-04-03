# =============================================
# Project Variables
# =============================================

MARKETPLACE_TOOLS_TAG ?= 0.11.1

# Define image tags
XTDB_TAG ?=  1.0.0

# Define image sources
PROJECT_ID ?= $(shell gcloud config get-value project)
REGISTRY ?= us-central1-docker.pkg.dev/bcs-test-450214/xtdb-repo

# Deployment namespace
NAMESPACE ?= xtdb-deployment

# GKE and infrastructure configuration
VPC_NAME ?= xtdb-vpc
VPC_SUBNET_NAME ?= xtdb-vpc-public-subnet
VPC_SUBNET_IP ?= 10.10.10.0/24
VPC_SUBNET_REGION ?= us-central1
KUBERNETES_CLUSTER_NAME ?= xtdb-cluster
KUBERNETES_CLUSTER_ZONE ?= us-central1
NODE_MACHINE_TYPE ?= n2-highmem-2
NODE_DISK_SIZE ?= 50
NODE_DISK_TYPE ?= pd-standard
NODE_COUNT ?= 1
EPHEMERAL_SSD_COUNT ?= 1

# Default deployment parameters
APP_PARAMETERS ?= { \
  "name": "xtdb-kubernetes-deployment", \
  "namespace": "$(NAMESPACE)", \
  "xtdb.serviceAccount": "xtdb-service-account", \
  "xtdbConfig.gcpProjectId": "$(PROJECT_ID)", \
	"xtdbConfig.gcpBucket": "xtdb-storage-$(PROJECT_ID)" \
}

# Build and deployment targets
.PHONY: check-vpc-name setup-xtdb-subnet setup-service-account setup-bucket setup-infra setup-namespace generate-tls update-deps build-deployer push-deployer workload-identity deploy verify mpdev-verify connect cleanup-deployment cleanup-infra setup-initial setup-deployment setup-all reboot-deployment cleanup-all help

# =============================================
# Infrastructure Setup (in chronological order)
# =============================================

# 1. Intro
intro:
	@echo "Welcome to the XTDB on GCP Marketplace deployment script."
	@echo "This script will guide you through the setup process."
	@echo "================================================================"
	@if [ -z "$(PROJECT_ID)" ]; then \
		echo "ERROR: Could not retrieve GCP Project ID."; \
		echo "Please ensure you are authenticated with gcloud and have set an active project:"; \
		echo "  1. Authenticate: gcloud auth login"; \
		echo "  2. Set Project:  gcloud config set project <your-project-id>"; \
		exit 1; \
	fi
	@echo "Using Project ID: $(PROJECT_ID)" # Confirm the project ID being used
	@echo "Ensure this is the correct project before proceeding."
	@echo "Also ensure you have enabled the required GCP APIs for this project."
	@read -p "Press Enter to confirm and continue..."

# 1.5 Check VPC Name
check-vpc-name:
	@echo "================================================================"
	@echo "Checking VPC network configuration..."
	@echo "Please enter the name of your existing VPC network (leave blank to create a new vpc called '$(VPC_NAME)'):"
	@read input_vpc_name; \
	if [ -z "$$input_vpc_name" ]; then \
		echo "$(VPC_NAME)" > .vpc_name; \
		echo "Using default VPC name: $(VPC_NAME)"; \
		echo "Creating VPC network..." \
		gcloud compute networks create $(VPC_NAME) \
			--project=$(PROJECT_ID) \
			--subnet-mode=custom; \
	else \
		echo "$$input_vpc_name" > .vpc_name; \
		echo "Using specified VPC name: $$input_vpc_name"; \
	fi

# 2. Setup XTDB Subnet
setup-xtdb-subnet:
	@echo "================================================================"
	@echo "Creating XTDB subnet in VPC '$$(cat .vpc_name)'..."
	gcloud compute networks subnets create $(VPC_SUBNET_NAME) \
		--project=$(PROJECT_ID) \
		--network=$$(cat .vpc_name) \
		--region=$(VPC_SUBNET_REGION) \
		--range=$(VPC_SUBNET_IP)

# 2. Setup service account (needed for both GKE and storage)
setup-service-account:
	@echo "================================================================"
	@echo "Next, we will create a Service Account for XTDB and configure the necessary permissions."
	@echo "Creating service account..."
	gcloud iam service-accounts create xtdb-service-account \
		--project=$(PROJECT_ID) \
		--display-name="XTDB Service Account" || true
	gcloud projects add-iam-policy-binding $(PROJECT_ID) \
		--member="serviceAccount:xtdb-service-account@$(PROJECT_ID).iam.gserviceaccount.com" \
		--role="roles/storage.admin"

# 3. Setup GCS bucket (storage for XTDB)
setup-bucket:
	@echo "================================================================"
	@echo "Then, we will create a GCS storage bucket specifically for XTDB."
	@echo "Creating GCS bucket..."
	gcloud storage buckets create gs://xtdb-storage-$(PROJECT_ID) \
		--project=$(PROJECT_ID) \
		--location=$(VPC_SUBNET_REGION) \
		--default-storage-class=STANDARD || true
# May want to look into possibly changing where the location is set to.

# 4. Setup GKE cluster with advanced configuration
setup-infra:
	@echo "================================================================"
	@echo "Then we need to setup the GKE cluster and node pools with advanced configuration."
	@echo "This will take a few minutes to complete."
	@echo "Creating GKE cluster configuration..."
	gcloud container clusters create $(KUBERNETES_CLUSTER_NAME) \
		--project=$(PROJECT_ID) \
		--zone=$(KUBERNETES_CLUSTER_ZONE) \
		--network=$$(cat .vpc_name) \
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

# =============================================
# Application Deployment
# =============================================

# 5. Setup namespace and Kubernetes service account
setup-namespace:
	@echo "Creating namespace and Kubernetes service account..."
	kubectl create namespace $(NAMESPACE) || true
	kubectl create serviceaccount xtdb-service-account --namespace $(NAMESPACE) || true

# 10. Setup workload identity
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

# 11. Deploy to test environment
deploy:
	@echo "Deploying XTDB..."
	kubectl apply -f "https://raw.githubusercontent.com/GoogleCloudPlatform/marketplace-k8s-app-tools/master/crd/app-crd.yaml"
	mpdev install --deployer=$(REGISTRY)/xtdb/deployer:$(XTDB_TAG) \
		--parameters='$(APP_PARAMETERS)' 
	@echo "Waiting for 30 seconds to allow XTDB to initialise..."
	@sleep 30

# 12. Verify deployment
verify:
	@echo "Verifying XTDB deployment..."
	kubectl get pods -n $(NAMESPACE)
	kubectl get svc xtdb-service -n xtdb-deployment

# 13. Connect to XTDB
connect:
	@echo "Connecting to XTDB..."
	@XTDB_IP=$$(kubectl get svc xtdb-service --namespace $(NAMESPACE) -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || echo "pending"); \
	if [ "$$XTDB_IP" = "pending" ]; then \
		echo "XTDB service IP is still pending. Please try again later."; \
	else \
		echo "XTDB is available at: $$XTDB_IP:5432"; \
		echo "Connection string: psql \"host=$$XTDB_IP port=5432 user=xtdb\""; \
		psql "host=$$XTDB_IP port=5432 user=xtdb"; \
	fi

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
	@if [ -f .vpc_name ]; then \
		echo "Attempting to delete VPC: $$(cat .vpc_name)"; \
		gcloud compute networks delete $$(cat .vpc_name) --quiet || true; \
		rm -f .vpc_name; \
	else \
		echo "No .vpc_name file found, attempting to delete default VPC: $(VPC_NAME)"; \
		gcloud compute networks delete $(VPC_NAME) --quiet || true; \
	fi

# =============================================
# Complete Setup and Cleanup
# =============================================

# Setup initial infrastructure
setup-initial: intro check-vpc-name setup-xtdb-subnet setup-service-account setup-bucket setup-infra

# Setup deployment (infrastructure + deployment)
setup-deployment: setup-namespace workload-identity deploy verify

# Complete setup (infrastructure + deployment) in chronological order
setup-all: setup-initial setup-deployment

# Reboot deployment
reboot-deployment: cleanup-deployment setup-deployment

# Complete cleanup (in reverse order)
cleanup-all: cleanup-deployment cleanup-infra

# =============================================
# Help Command
# =============================================

help:
	@echo "XTDB on GCP Marketplace - Makefile Commands"
	@echo ""
	@echo "Infrastructure Setup Commands:"
	@echo "  intro                    Display introduction message"
	@echo "  check-vpc-name           Prompt for VPC name and store it"
	@echo "  setup-xtdb-subnet        Create the XTDB subnet within the specified/default VPC"
	@echo "  setup-service-account    Create and configure GCP service account"
	@echo "  setup-bucket             Create GCS bucket for XTDB storage"
	@echo "  setup-infra              Setup GKE cluster with node pools"
	@echo "  setup-namespace          Create Kubernetes namespace and service account"
	@echo "  workload-identity        Configure GCP/Kubernetes workload identity"
	@echo "  setup-initial            Run all infrastructure setup commands in sequence"
	@echo ""
	@echo "Application Commands:"
	@echo "  update-deps              Update Helm dependencies"
	@echo "  build-deployer           Build the XTDB deployer image"
	@echo "  push-deployer            Push the deployer image to registry"
	@echo "  deploy                   Deploy XTDB to Kubernetes"
	@echo "  verify                   Verify XTDB deployment status"
	@echo "  mpdev-verify             Verify deployer using mpdev tools"
	@echo "  connect                  Connect to XTDB instance via psql"
	@echo "  setup-deployment         Run all deployment commands in sequence"
	@echo ""
	@echo "Complete Workflows:"
	@echo "  setup-all                Setup infrastructure and deploy XTDB"
	@echo "  reboot-deployment        Clean up and redeploy XTDB"
	@echo ""
	@echo "Cleanup Commands:"
	@echo "  cleanup-deployment       Remove XTDB Kubernetes resources"
	@echo "  cleanup-infra            Remove all GCP infrastructure"
	@echo "  cleanup-all              Run all cleanup commands in sequence"
	@echo ""
	@echo "Example usage:"
	@echo "  make setup-all           # Complete setup from scratch"
	@echo "  make connect             # Connect to deployed XTDB instance"
	@echo "  make cleanup-all         # Clean up everything"
