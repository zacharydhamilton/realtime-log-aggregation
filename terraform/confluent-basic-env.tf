terraform {
    required_providers {
        confluent = {
            source = "confluentinc/confluent"
            version = "1.24.0"
        }
    }
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
resource "confluent_environment" "env" {
    display_name = "${local.env_name}-${random_id.id.hex}"
    lifecycle {
        prevent_destroy = false
    }
}
# --------------------------------------------------------
# Schema Registry
# --------------------------------------------------------
data "confluent_schema_registry_region" "sr_region" {
    cloud = "AWS"
    region = "${local.aws_region}"
    package = "ADVANCED" 
}
resource "confluent_schema_registry_cluster" "sr_cluster" {
    package = data.confluent_schema_registry_region.sr_region.package
    environment {
        id = confluent_environment.env.id 
    }
    region {
        id = data.confluent_schema_registry_region.sr_region.id
    }
    lifecycle {
        prevent_destroy = false
    }
}
# --------------------------------------------------------
# Kafka Cluster
# --------------------------------------------------------
resource "confluent_kafka_cluster" "kafka_cluster" {
    display_name = "${local.cluster_name}"
    availability = "SINGLE_ZONE"
    cloud = "AWS"
    region = "${local.aws_region}"
    basic {}
    environment {
        id = confluent_environment.env.id
    }
    lifecycle {
        prevent_destroy = false
    }
}
# --------------------------------------------------------
# Ksql Cluster
# --------------------------------------------------------
resource "confluent_ksql_cluster" "ksql_cluster" {
    display_name = "ksql-cluster-${random_id.id.hex}"
    csu = 2
    environment {
        id = confluent_environment.env.id
    }
    kafka_cluster {
        id = confluent_kafka_cluster.kafka_cluster.id
    }
    credential_identity {
        id = confluent_service_account.ksql.id
    }
    depends_on = [
        confluent_role_binding.ksql_kafka_cluster_admin,
        confluent_role_binding.ksql_sr_resource_owner,
        confluent_api_key.ksql_kafka_cluster_key,
        confluent_schema_registry_cluster.sr_cluster
    ]
}
# --------------------------------------------------------
# Kafka topics
# --------------------------------------------------------
resource "confluent_kafka_topic" "topics" {
    for_each = toset(local.topics)
    kafka_cluster {
        id = confluent_kafka_cluster.kafka_cluster.id
    }
    topic_name = each.key
    rest_endpoint = confluent_kafka_cluster.kafka_cluster.rest_endpoint
    credentials {
        key = confluent_api_key.app_manager_kafka_cluster_key.id
        secret = confluent_api_key.app_manager_kafka_cluster_key.secret
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
# Schema Registry SA
# --------------------------------------------------------
resource "confluent_service_account" "sr" {
    display_name = "sr-sa-${random_id.id.hex}"
    description = "${local.description}"
}
# --------------------------------------------------------
# Ksql SA
# --------------------------------------------------------
resource "confluent_service_account" "ksql" {
    display_name = "ksql-sa-${random_id.id.hex}"
    description = "${local.description}"
}
# --------------------------------------------------------
# 'clients' will be the SA used to pass created keys to
# things like Connectors, Kafka Producers and Consumers, etc
# --------------------------------------------------------
resource "confluent_service_account" "clients" {
    display_name = "client-sa-${random_id.id.hex}"
    description = "${local.description}"
}
# --------------------------------------------------------
# Give the provisioning SA EnvironmentAdmin so it doesn't
# run into any issues
# --------------------------------------------------------
resource "confluent_role_binding" "app_manager_environment_admin" {
    principal = "User:${confluent_service_account.app_manager.id}"
    role_name = "EnvironmentAdmin"
    crn_pattern = confluent_environment.env.resource_name
}
# --------------------------------------------------------
# Schema Registry Role Binding
# --------------------------------------------------------
resource "confluent_role_binding" "sr_resource_owner" {
    principal = "User:${confluent_service_account.sr.id}"
    role_name = "ResourceOwner"
    crn_pattern = format("%s/%s", confluent_schema_registry_cluster.sr_cluster.resource_name, "subject=*")
}
# --------------------------------------------------------
# Ksql Role Bindings
# --------------------------------------------------------
resource "confluent_role_binding" "ksql_kafka_cluster_admin" {
    principal = "User:${confluent_service_account.ksql.id}"
    role_name = "CloudClusterAdmin"
    crn_pattern = confluent_kafka_cluster.kafka_cluster.rbac_crn
}
resource "confluent_role_binding" "ksql_sr_resource_owner" {
    principal = "User:${confluent_service_account.ksql.id}"
    role_name = "ResourceOwner"
    crn_pattern = format("%s/%s", confluent_schema_registry_cluster.sr_cluster.resource_name, "subject=*")
}
# --------------------------------------------------------
# Give the client SA CloudClusterAdmin to it can be used
# within the cluster for pretty much anything
# --------------------------------------------------------
resource "confluent_role_binding" "clients_cluster_admin" {
    principal = "User:${confluent_service_account.clients.id}"
    role_name = "CloudClusterAdmin"
    crn_pattern = confluent_kafka_cluster.kafka_cluster.rbac_crn
}
# --------------------------------------------------------
# Create the credentials for the provisioning SA
# --------------------------------------------------------
resource "confluent_api_key" "app_manager_kafka_cluster_key" {
    display_name = "app-manager-${local.cluster_name}-key-${random_id.id.hex}"
    description = "${local.description}"
    owner {
        id = confluent_service_account.app_manager.id
        api_version = confluent_service_account.app_manager.api_version
        kind = confluent_service_account.app_manager.kind
    }
    managed_resource {
        id = confluent_kafka_cluster.kafka_cluster.id
        api_version = confluent_kafka_cluster.kafka_cluster.api_version
        kind = confluent_kafka_cluster.kafka_cluster.kind
        environment {
            id = confluent_environment.env.id
        }
    }
    depends_on = [
        confluent_role_binding.app_manager_environment_admin
    ]
}
# --------------------------------------------------------
# Schema Registry API Key
# --------------------------------------------------------
resource "confluent_api_key" "sr_cluster_key" {
    display_name = "sr-${local.cluster_name}-key-${random_id.id.hex}"
    description = "${local.description}"
    owner {
        id = confluent_service_account.sr.id 
        api_version = confluent_service_account.sr.api_version
        kind = confluent_service_account.sr.kind
    }
    managed_resource {
        id = confluent_schema_registry_cluster.sr_cluster.id
        api_version = confluent_schema_registry_cluster.sr_cluster.api_version
        kind = confluent_schema_registry_cluster.sr_cluster.kind 
        environment {
            id = confluent_environment.env.id
        }
    }
    depends_on = [
      confluent_role_binding.sr_resource_owner
    ]
}
# --------------------------------------------------------
# Ksql Kafka Cluster API Key
# --------------------------------------------------------
resource "confluent_api_key" "ksql_kafka_cluster_key" {
    display_name = "ksql-${local.cluster_name}-key-${random_id.id.hex}"
    description = "${local.description}"
    owner {
        id = confluent_service_account.ksql.id
        api_version = confluent_service_account.ksql.api_version
        kind = confluent_service_account.ksql.kind
    }
    managed_resource {
        id = confluent_kafka_cluster.kafka_cluster.id 
        api_version = confluent_kafka_cluster.kafka_cluster.api_version
        kind = confluent_kafka_cluster.kafka_cluster.kind
        environment {
            id = confluent_environment.env.id
        }
    }
    depends_on = [
        confluent_role_binding.ksql_kafka_cluster_admin, 
        confluent_role_binding.ksql_sr_resource_owner
    ]
}
# --------------------------------------------------------
# Create the credentials for the clients SA
# --------------------------------------------------------
resource "confluent_api_key" "clients_kafka_cluster_key" {
    display_name = "clients-${local.cluster_name}-key-${random_id.id.hex}"
    description = "${local.description}"
    owner {
        id = confluent_service_account.clients.id
        api_version = confluent_service_account.clients.api_version
        kind = confluent_service_account.clients.kind
    }
    managed_resource {
        id = confluent_kafka_cluster.kafka_cluster.id
        api_version = confluent_kafka_cluster.kafka_cluster.api_version
        kind = confluent_kafka_cluster.kafka_cluster.kind
        environment {
            id = confluent_environment.env.id
        }
    }
    depends_on = [
        confluent_role_binding.clients_cluster_admin
    ]
}

# ------------------------------------------------------------
# Output files
# ------------------------------------------------------------
data "template_file" "secrets_template" {
    template = "${file("../secrets.tmpl")}"
    vars = {
        bootstrap_server = substr(confluent_kafka_cluster.kafka_cluster.bootstrap_endpoint,11,-1)
        kafka_cluster_key = confluent_api_key.clients_kafka_cluster_key.id
        kafka_cluster_secret = confluent_api_key.clients_kafka_cluster_key.secret
    }
}
resource "local_file" "secrets_sh" {
    filename = "../secrets.sh"
    content = data.template_file.secrets_template.rendered
}
