# XTDB Google Cloud Deployment Makefile
# Project variables are determined during deployment and stored in temp files

# Default configuration variables
CHART_NAME := xtdb
APP_ID ?= $(CHART_NAME)

# Track and version information
TRACK ?= 1.0.0
MARKETPLACE_TOOLS_TAG ?= 0.11.1

# Define image tags
XTDB_TAG ?= $(TRACK)
KAFKA_TAG ?= 31.3.1

# Default image references without project-specific values
# (Project-specific registry values will be constructed at runtime using .project_id)
IMAGE_KAFKA ?= docker.io/bitnami/kafka:$(KAFKA_TAG)

# Build ID and release info
BUILD_ID := $(shell date --utc +%Y%m%d-%H%M%S)
RELEASE ?= $(XTDB_TAG)-$(BUILD_ID)
NAME ?= $(APP_ID)-1

# Deployment namespace
NAMESPACE ?= xtdb-deployment

# GKE and infrastructure configuration
VPC_NAME ?= xtdb-vpc
VPC_SUBNET_NAME ?= $(VPC_NAME)-public-subnet
VPC_SUBNET_IP ?= 10.10.10.0/24
VPC_SUBNET_REGION ?= us-central1
KUBERNETES_CLUSTER_NAME ?= xtdb-cluster
KUBERNETES_CLUSTER_REGION ?= us-central1
NODE_MACHINE_TYPE ?= n2-highmem-2
NODE_DISK_SIZE ?= 50
NODE_DISK_TYPE ?= pd-standard
NODE_COUNT ?= 1
EPHEMERAL_SSD_COUNT ?= 1
SERVICE_ACCOUNT ?= xtdb-service-account
HELM_CHART_PATH ?= ./helm
HELM_CHART_VERSION ?= 2.0.0-snapshot
NODE_POOL ?= xtdb-pool
DOCKER_REPO ?= quickstart-docker-repo

# Build and deployment targets
.PHONY: check-installs check-project-id-bucket gcloud-init run-terraform deploy-clusters install-kafka setup-workload-identity install-xtdb verify cleanup-deployment delete-container-registry cleanup-infra cleanup-all prep-marketplace setup-mpdev setup-helm status get-xtdb-url help

# =============================================
# Infrastructure Setup (in chronological order)
# =============================================

# 0a. Check installs
check-installs:
	@echo "Checking installs..."
	@missing=""
	@command -v gcloud >/dev/null 2>&1 || { missing="$$missing gcloud"; }
	@command -v terraform >/dev/null 2>&1 || { missing="$$missing terraform"; }
	@command -v kubectl >/dev/null 2>&1 || { missing="$$missing kubectl"; }
	@command -v helm >/dev/null 2>&1 || { missing="$$missing helm"; }
	@if [ -n "$$missing" ]; then \
		echo "ERROR: The following required tools are not installed:$$missing"; \
		echo "Please install the missing tools before continuing."; \
		exit 1; \
	else \
		echo "All required tools are installed. Ready to proceed."; \
	fi

# 0b. Check project ID
check-project-id-bucket:
	@echo "Checking terraform.tfvars file..."
	@if grep -q "^# project_id" terraform/terraform.tfvars; then \
		echo "project_id line is commented. Let's uncomment it."; \
		echo "Please enter your GCP project ID:"; \
		read input_project_id; \
		if [ -z "$$input_project_id" ]; then \
			echo "ERROR: No project ID provided."; \
			exit 1; \
		fi; \
		sed -i '2s|^# project_id.*|project_id = "'"$$input_project_id"'"|' terraform/terraform.tfvars; \
		echo "Updated project_id to $$input_project_id in terraform.tfvars"; \
		echo "$$input_project_id" > .project_id; \
	else \
		current_project_id=$$(grep -oP 'project_id\s*=\s*"\K[^"]+' terraform/terraform.tfvars); \
		echo "project_id is already set to '$$current_project_id' in terraform.tfvars"; \
		echo "Do you want to change it? (y/n)"; \
		read change_project_id; \
		if [ "$$change_project_id" = "y" ] || [ "$$change_project_id" = "Y" ]; then \
			echo "Please enter your new GCP project ID:"; \
			read input_project_id; \
			if [ -z "$$input_project_id" ]; then \
				echo "No project ID provided. Keeping existing value."; \
				echo "$$current_project_id" > .project_id; \
			else \
				sed -i '2s|project_id.*|project_id = "'"$$input_project_id"'"|' terraform/terraform.tfvars; \
				echo "Updated project_id to $$input_project_id in terraform.tfvars"; \
				echo "$$input_project_id" > .project_id; \
			fi; \
		else \
			echo "Keeping existing project_id."; \
			echo "$$current_project_id" > .project_id; \
		fi; \
	fi; \
	if grep -q "^# storage_bucket_name" terraform/terraform.tfvars; then \
		echo "storage_bucket_name line is commented. Let's uncomment it."; \
		echo "Please enter your GCS storage bucket name:"; \
		read input_bucket_name; \
		if [ -z "$$input_bucket_name" ]; then \
			echo "ERROR: No storage bucket name provided."; \
			exit 1; \
		fi; \
		sed -i '8s|^# storage_bucket_name.*|storage_bucket_name        = "'"$$input_bucket_name"'"|' terraform/terraform.tfvars; \
		echo "Updated storage_bucket_name to $$input_bucket_name in terraform.tfvars"; \
		echo "$$input_bucket_name" > .storage_bucket; \
	else \
		current_bucket_name=$$(grep -oP 'storage_bucket_name\s*=\s*"\K[^"]+' terraform/terraform.tfvars); \
		echo "storage_bucket_name is already set to '$$current_bucket_name' in terraform.tfvars"; \
		echo "Do you want to change it? (y/n)"; \
		read change_bucket_name; \
		if [ "$$change_bucket_name" = "y" ] || [ "$$change_bucket_name" = "Y" ]; then \
			echo "Please enter your new GCS storage bucket name:"; \
			read input_bucket_name; \
			if [ -z "$$input_bucket_name" ]; then \
				echo "No storage bucket name provided. Keeping existing value."; \
				echo "$$current_bucket_name" > .storage_bucket; \
			else \
				sed -i '8s|storage_bucket_name.*|storage_bucket_name        = "'"$$input_bucket_name"'"|' terraform/terraform.tfvars; \
				echo "Updated storage_bucket_name to $$input_bucket_name in terraform.tfvars"; \
				echo "$$input_bucket_name" > .storage_bucket; \
			fi; \
		else \
			echo "Keeping existing storage_bucket_name."; \
			echo "$$current_bucket_name" > .storage_bucket; \
		fi; \
	fi; \
	echo "PROJECT_ID is now set to $$(cat .project_id)"; \
	echo "STORAGE_BUCKET is now set to $$(cat .storage_bucket)"

# 1. Initialise gcloud
gcloud-init:
	@echo "Do you need to initialise gcloud? (y/n)"
	@read -r answer; \
	if [ "$$answer" = "y" ] || [ "$$answer" = "Y" ]; then \
		echo "Initialising gcloud..."; \
		gcloud init; \
	else \
		echo "Skipping gcloud initialisation."; \
	fi

# 2. Terraform setup with user input
run-terraform:
	@echo "Running Terraform commands with user-provided values..."
	cd terraform && \
	terraform init && \
	terraform apply -auto-approve

# 2. Deploy GKE clusters and namespaces
deploy-clusters:
	@echo "Deploying GKE clusters..."
	gcloud container clusters get-credentials $(KUBERNETES_CLUSTER_NAME) --region $(KUBERNETES_CLUSTER_REGION)
	kubectl create namespace $(NAMESPACE)

# 3. Install Kafka
install-kafka:
	@echo "Installing Kafka..."
	helm install kafka oci://registry-1.docker.io/bitnamicharts/kafka --version $(KAFKA_TAG) --namespace $(NAMESPACE) --set listeners.client.protocol=PLAINTEXT --set listeners.controller.protocol=PLAINTEXT --set controller.resourcesPreset=medium --set controller.nodeSelector.node_pool=$(NODE_POOL)

# 4. Create workload identity
setup-workload-identity: 
	@echo "Setting up workload identity..."
	kubectl create serviceaccount $(SERVICE_ACCOUNT) --namespace $(NAMESPACE)
	@export PROJECT_ID=$$(cat .project_id); \
	gcloud iam service-accounts add-iam-policy-binding $(SERVICE_ACCOUNT)@$$PROJECT_ID.iam.gserviceaccount.com --role roles/iam.workloadIdentityUser --member "serviceAccount:$$PROJECT_ID.svc.id.goog[$(NAMESPACE)/$(SERVICE_ACCOUNT)]"
	@export PROJECT_ID=$$(cat .project_id); \
	kubectl annotate serviceaccount $(SERVICE_ACCOUNT) --namespace $(NAMESPACE) iam.gke.io/gcp-service-account=$(SERVICE_ACCOUNT)@$$PROJECT_ID.iam.gserviceaccount.com

# 5. Install XTDB
install-xtdb:
	@echo "Installing XTDB..."
	@export PROJECT_ID=$$(cat .project_id); \
	export STORAGE_BUCKET=$$(cat .storage_bucket); \
	helm install xtdb-google-cloud $(HELM_CHART_PATH) --version $(HELM_CHART_VERSION) --namespace $(NAMESPACE) --set xtdbConfig.serviceAccount=$(SERVICE_ACCOUNT) --set xtdbConfig.gcpProjectId=$$PROJECT_ID --set xtdbConfig.gcpBucket=$$STORAGE_BUCKET
	@echo "Waiting for 1 minute to allow XTDB to initialise..."
	@sleep 90

#	6. Remove temporary files
delete-temp:
	@echo "Removing temporary files..."
	rm -f .project_id .storage_bucket

# =============================================
# Verification and Connection
# =============================================

# 7. Verify deployment
verify: 
	@echo "Verifying XTDB deployment..."
	kubectl get pods -n $(NAMESPACE)
	kubectl get services -n $(NAMESPACE)

# 8. Connect to XTDB
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

# 1. Delete clusters
delete-clusters:
	@echo "Deleting GKE clusters..."
	gcloud container clusters delete $(KUBERNETES_CLUSTER_NAME) --region=$(KUBERNETES_CLUSTER_REGION) --quiet || true

# 2. Delete storage bucket
delete-storage-bucket: check-project-id-bucket
	@echo "Deleting storage bucket..."
	@export STORAGE_BUCKET=$$(cat .storage_bucket); \
	gcloud storage rm -r gs://$$STORAGE_BUCKET --quiet || true
	rm -f .project_id .storage_bucket

# 3. Delete subnets and VPC
delete-subnets-vpc:
	@echo "Deleting subnets and VPC..."
	gcloud compute networks subnets delete $(VPC_SUBNET_NAME) --region=$(VPC_SUBNET_REGION) --quiet || true
	gcloud compute networks delete $(VPC_NAME) --quiet || true

# 4. Destroy Terraform
destroy-terraform:
	@echo "Destroying Terraform..."
	cd terraform && terraform destroy -auto-approve

# =============================================
# Complete Setup and Cleanup
# =============================================

# Main deployment targets
setup: check-installs check-project-id-bucket gcloud-init run-terraform deploy-clusters install-kafka setup-workload-identity install-xtdb delete-temp

# Main cleanup target
cleanup: delete-clusters delete-storage-bucket delete-subnets-vpc destroy-terraform

# =============================================
# Help Commands
# =============================================

# Help command
help:
	@echo "===================================================================="
	@echo "XTDB on Google Cloud - Deployment Helper"
	@echo "===================================================================="
	@echo ""
	@echo "MAIN WORKFLOWS:"
	@echo "  make setup              Complete setup workflow (recommended for first-time setup)"
	@echo "  make cleanup            Complete cleanup workflow"
	@echo ""
	@echo "SETUP COMMANDS (in order of typical usage):"
	@echo "  make check-installs     Check if required tools are installed"
	@echo "  make check-project-id-bucket  Configure project ID and storage bucket name"
	@echo "  make gcloud-init        Initialize Google Cloud CLI"
	@echo "  make run-terraform      Run Terraform to create infrastructure"
	@echo "  make deploy-clusters    Deploy GKE clusters and create namespace"
	@echo "  make install-kafka      Install Kafka using Helm"
	@echo "  make setup-workload-identity  Set up GCP workload identity"
	@echo "  make install-xtdb       Install XTDB on the cluster"
	@echo "  make delete-temp        Remove temporary files created during setup"
	@echo ""
	@echo "OPERATION COMMANDS:"
	@echo "  make verify             Verify XTDB deployment status"
	@echo "  make connect            Connect to XTDB with PostgreSQL client"
	@echo ""
	@echo "CLEANUP COMMANDS (in reverse order):"
	@echo "  make delete-clusters    Delete GKE clusters"
	@echo "  make delete-storage-bucket  Delete GCS storage bucket"
	@echo "  make delete-subnets-vpc Delete subnets and VPC"
	@echo "  make destroy-terraform  Run Terraform destroy"
	@echo ""
	@echo "For more information, see the documentation at: https://github.com/xtdb/xtdb"
	@echo "===================================================================="