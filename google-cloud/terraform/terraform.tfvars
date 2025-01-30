# Google Cloud Project
project_id = ""

# Google Cloud Storage Settings
storage_bucket_name          = "xtdb-storage-bucket"
storage_bucket_location      = "us-central1"
storage_bucket_storage_class = "STANDARD"

# Key GKE Config
kubernetes_cluster_name   = "xtdb-cluster"
kubernetes_cluster_region = "us-central1"
kubernetes_cluster_zones  = ["us-central1-a"]

# VPC/Network naming for GKE
kubernetes_vpc_name          = "xtdb-vpc-01"
kubernetes_subnetwork_name   = "us-central1-01"
kubernetes_ip_range_pods     = "us-central1-01-gke-01-pods"
kubernetes_ip_range_services = "us-central1-01-gke-01-services"

# GKE System Node Pool Settings
system_node_pool_machine_type = "n2-standard-2"
system_node_pool_locations    = "us-central1-a"
system_node_pool_min_count    = 1
system_node_pool_max_count    = 1
system_node_pool_disk_size_gb = 10
system_node_pool_disk_type    = "pd-standard"

# GKE Application Node Pool Settings
application_node_pool_machine_type = "n2-standard-8"
application_node_pool_locations    = "us-central1-a"
application_node_pool_min_count    = 1
application_node_pool_max_count    = 1
application_node_pool_disk_size_gb = 200
application_node_pool_disk_type    = "pd-ssd"
