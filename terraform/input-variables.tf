locals {
    env_name = "log-aggregation-and-analytics"
    cluster_name = "basic-kafka-cluster"
    description = "Resource for the 'Log Aggregation and Analytics' workshop."
    aws_region = "us-east-2"
    topics = ["java-app-1", "java-app-2", "java-apps", "logs-raw", "logs-enriched", "events", "anomalies"]
}