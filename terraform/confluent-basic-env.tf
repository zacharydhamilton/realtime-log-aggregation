terraform {
    required_providers {
        confluent = {
            source = "confluentinc/confluent"
            version = "1.13.0"
        }
        local = {
            source = "hashicorp/local"
            version = "2.2.3"
        }
        template = {
            source = "hashicorp/template"
            version = "2.2.0"
        }
    }
}

provider "confluent" {
    # Set through env vars as:
    # CONFLUENT_CLOUD_API_KEY="CLOUD-KEY"
    # CONFLUENT_CLOUD_API_SECRET="CLOUD-SECRET"
}
provider "local" {
    # For writing configs to a file
}
# --------------------------------------------------------
# This 'random_id' should hopefully make whatever you create
# unique in your account.
# --------------------------------------------------------
resource "random_id" "id" {
    byte_length = 4
}
# --------------------------------------------------------
# This resource should be named by changing the 'env_name'
# variable in 'input-variables.tf'
# --------------------------------------------------------
resource "confluent_environment" "basic_env" {
    display_name = "${local.env_name}-${random_id.id.hex}"
    lifecycle {
        prevent_destroy = false
    }
}
# --------------------------------------------------------
# This resource should be named by changing the 'cluster_name'
# varible in 'input-variables.tf'
# --------------------------------------------------------
resource "confluent_kafka_cluster" "basic_cluster" {
    display_name = "${local.cluster_name}"
    availability = "SINGLE_ZONE"
    cloud = "AWS"
    region = "us-east-2"
    basic {}
    environment {
        id = confluent_environment.basic_env.id
    }
    lifecycle {
        prevent_destroy = false
    }
}
# --------------------------------------------------------
# 'app_manager' will act as the provisioning SA 
# --------------------------------------------------------
resource "confluent_service_account" "app_manager" {
    display_name = "app-manager-${random_id.id.hex}"
    description = "${local.description}"
}
# --------------------------------------------------------
# 'clients' will be the SA used to pass created keys to
# things like Connectors, Kafka Producers and Consumers, etc
# --------------------------------------------------------
resource "confluent_service_account" "clients" {
    display_name = "client-${random_id.id.hex}"
    description = "${local.description}"
}
# --------------------------------------------------------
# Give the provisioning SA EnvironmentAdmin so it doesn't
# run into any issues
# --------------------------------------------------------
resource "confluent_role_binding" "app_manager_environment_admin" {
    principal = "User:${confluent_service_account.app_manager.id}"
    role_name = "EnvironmentAdmin"
    crn_pattern = confluent_environment.basic_env.resource_name
}
# --------------------------------------------------------
# Give the client SA CloudClusterAdmin to it can be used
# within the cluster for pretty much anything
# --------------------------------------------------------
resource "confluent_role_binding" "clients_cluster_admin" {
    principal = "User:${confluent_service_account.clients.id}"
    role_name = "CloudClusterAdmin"
    crn_pattern = confluent_kafka_cluster.basic_cluster.rbac_crn
}
# --------------------------------------------------------
# Create the credentials for the provisioning SA
# --------------------------------------------------------
resource "confluent_api_key" "app_manager_basic_cluster_key" {
    display_name = "app-manager-${local.cluster_name}-key-${random_id.id.hex}"
    description = "${local.description}"
    owner {
        id = confluent_service_account.app_manager.id
        api_version = confluent_service_account.app_manager.api_version
        kind = confluent_service_account.app_manager.kind
    }
    managed_resource {
        id = confluent_kafka_cluster.basic_cluster.id
        api_version = confluent_kafka_cluster.basic_cluster.api_version
        kind = confluent_kafka_cluster.basic_cluster.kind
        environment {
            id = confluent_environment.basic_env.id
        }
    }
    depends_on = [
        confluent_role_binding.app_manager_environment_admin
    ]
}
# --------------------------------------------------------
# Create the credentials for the clients SA
# --------------------------------------------------------
resource "confluent_api_key" "clients_basic_cluster_key" {
    display_name = "clients-${local.cluster_name}-key-${random_id.id.hex}"
    description = "${local.description}"
    owner {
        id = confluent_service_account.clients.id
        api_version = confluent_service_account.clients.api_version
        kind = confluent_service_account.clients.kind
    }
    managed_resource {
        id = confluent_kafka_cluster.basic_cluster.id
        api_version = confluent_kafka_cluster.basic_cluster.api_version
        kind = confluent_kafka_cluster.basic_cluster.kind
        environment {
            id = confluent_environment.basic_env.id
        }
    }
    depends_on = [
        confluent_role_binding.clients_cluster_admin
    ]
}
# ------------------------------------------------------------
# As a basic example, this template file will act as a target for 
# the values created by Terraform
# ------------------------------------------------------------
data "template_file" "client_properties_template" {
    template = "${file("client.tmpl")}"
    vars = {
        bootstrap_server = substr(confluent_kafka_cluster.basic_cluster.bootstrap_endpoint,11,-1)
        kafka_cluster_key = confluent_api_key.clients_basic_cluster_key.id
        kafka_cluster_secret = confluent_api_key.clients_basic_cluster_key.secret
    }
}
# --------------------------------------------------------
# The values injected into the template can be rended into a 
# file that could be used elsewhere
# --------------------------------------------------------
resource "local_file" "client_properties" {
    filename = "client.properties"
    content = data.template_file.client_properties_template.rendered
}
