variable "project_id" {
  description = "Existing Google Cloud Project ID to deploy the XTDB infrastructure into."
  type        = string
  validation {
    condition     = length(var.storage_account_name) >= 0
    error_message = "The Google cloud project ID must be set."
  }
}

variable "storage_bucket_name" {
  description = "The name of the Google Cloud Storage bucket used for XTDB data storage."
  type        = string
  default     = "xtdb-storage-bucket"
}

variable "storage_bucket_location" {
  description = "The geographical region where the Google Cloud Storage bucket will be created."
  type        = string
  default     = "us-central1"
}

variable "storage_bucket_storage_class" {
  description = "The storage class for the Google Cloud Storage bucket, defining performance and cost (e.g., STANDARD, NEARLINE, COLDLINE)."
  type        = string
  default     = "STANDARD"
}

variable "kubernetes_cluster_name" {
  description = "The name of the Google Kubernetes Engine (GKE) cluster for XTDB deployment."
  type        = string
  default     = "xtdb-cluster"
}

variable "kubernetes_cluster_region" {
  description = "The region where the GKE cluster will be deployed."
  type        = string
  default     = "us-central1"
}

variable "kubernetes_cluster_zones" {
  description = "The list of zones within the selected region where the GKE cluster nodes will be distributed."
  type        = list(string)
  default     = ["us-central1-a"]
}

variable "kubernetes_vpc_name" {
  description = "The name of the Virtual Private Cloud (VPC) network used by the GKE cluster."
  type        = string
  default     = "xtdb-vpc-01"
}

variable "kubernetes_subnetwork_name" {
  description = "The name of the subnetwork within the VPC for GKE cluster communication."
  type        = string
  default     = "us-central1-01"
}

variable "kubernetes_ip_range_pods" {
  description = "The custom IP address range allocated for GKE pods."
  type        = string
  default     = "us-central1-01-gke-01-pods"
}

variable "kubernetes_ip_range_services" {
  description = "The custom IP address range allocated for GKE services."
  type        = string
  default     = "us-central1-01-gke-01-services"
}

variable "system_node_pool_machine_type" {
  description = "The machine type for nodes in the GKE system node pool."
  type        = string
  default     = "n2-standard-2"
}

variable "system_node_pool_locations" {
  description = "The specific zones where system node pool nodes will be deployed."
  type        = string
  default     = "us-central1-a"
}

variable "system_node_pool_min_count" {
  description = "The minimum number of nodes to maintain in the system node pool."
  type        = number
  default     = 1
}

variable "system_node_pool_max_count" {
  description = "The maximum number of nodes allowed in the system node pool."
  type        = number
  default     = 1
}

variable "system_node_pool_disk_size_gb" {
  description = "The disk size (in GB) allocated to each node in the system node pool."
  type        = number
  default     = 10
}

variable "system_node_pool_disk_type" {
  description = "The type of persistent disk used for system node pool nodes (e.g., pd-standard, pd-ssd)."
  type        = string
  default     = "pd-standard"
}

variable "application_node_pool_machine_type" {
  description = "The machine type for nodes in the GKE application node pool, optimized for XTDB workloads."
  type        = string
  default     = "n2-standard-8"
}

variable "application_node_pool_locations" {
  description = "The specific zones where application node pool nodes will be deployed."
  type        = string
  default     = "us-central1-a"
}

variable "application_node_pool_min_count" {
  description = "The minimum number of nodes to maintain in the application node pool."
  type        = number
  default     = 1
}

variable "application_node_pool_max_count" {
  description = "The maximum number of nodes allowed in the application node pool."
  type        = number
  default     = 1
}

variable "application_node_pool_disk_size_gb" {
  description = "The disk size (in GB) allocated to each node in the application node pool."
  type        = number
  default     = 200
}

variable "application_node_pool_disk_type" {
  description = "The type of persistent disk used for application node pool nodes (e.g., pd-standard, pd-ssd)."
  type        = string
  default     = "pd-ssd"
}
