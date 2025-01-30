resource "google_service_account" "xtdb_service_account" {
  project = var.project_id

  account_id   = var.service_account_name
  display_name = "XTDB Service Account"
}

module "xtdb_storage" {
  source  = "terraform-google-modules/cloud-storage/google"
  version = "~> 9.0"

  project_id = var.project_id

  # Storage bucket settings
  names         = [var.storage_bucket_name]
  location      = var.storage_bucket_location
  storage_class = var.storage_bucket_storage_class

  # Role assignments
  set_admin_roles = true
  bucket_admins = {
    admins = google_service_account.xtdb_service_account.email
  }
}

module "kubernetes_engine" {
  source  = "terraform-google-modules/kubernetes-engine/google"
  version = "35.0.1"

  project_id = var.project_id

  name   = var.kubernetes_cluster_name
  region = var.kubernetes_cluster_region
  zones  = var.kubernetes_cluster_zones

  network           = var.kubernetes_vpc_name
  subnetwork        = var.kubernetes_subnetwork_name
  ip_range_pods     = var.kubernetes_ip_range_pods
  ip_range_services = var.kubernetes_ip_range_servicess

  node_pools = [
    {
      name            = "system-node-pool"
      machine_type    = var.system_node_pool_machine_type
      node_locations  = var.system_node_pool_locations
      min_count       = var.system_node_pool_min_count
      max_count       = var.system_node_pool_max_count
      disk_size_gb    = var.system_node_pool_disk_size_gb
      disk_type       = var.system_node_pool_disk_type
      auto_repair     = true
      auto_upgrade    = true
      service_account = google_service_account.xtdb_service_account.email
    },
    {
      name            = "xtdb-pool"
      machine_type    = var.application_node_pool_machine_type
      node_locations  = var.application_node_pool_locations
      min_count       = var.application_node_pool_min_count
      max_count       = var.application_node_pool_max_count
      disk_size_gb    = var.application_node_pool_disk_size_gb
      disk_type       = var.application_node_pool_disk_type
      auto_repair     = true
      auto_upgrade    = true
      service_account = google_service_account.xtdb_service_account.email
    }
  ]
}

