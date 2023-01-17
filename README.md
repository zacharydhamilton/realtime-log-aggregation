<div align="center" padding=25px>
    <img src="images/confluent.png" width=50% height=50%>
</div>

# <div align="center">Real-time Log Aggregation and Enrichment</div>
## <div align="center">Workshop & Lab Guide</div>

## Background

The goal of this workshop/lab is to provide examples of the things you can do with Kafka when aggregating and collecting log data from various sources. The core pieces that will be used in order to complete the end-to-end example will be the follow: 
- Java fake logging application
- Fluent-bit 
- Confluent Cloud
- KsqlDB
- Filebeat
- Elasticsearch (7.10.1, the last open-source version)
- Kibana (7.10.1, the last open-source version)

***

## Prerequisites

In order to go through this complete lab guide, you will need a variety of things. Prior to going through this guide, please have the following:
- Confluent Cloud Account ([Free Trial](https://www.confluent.io/confluent-cloud/tryfree/))
- Terraform
- Docker

In order to have this work when they're actually running, you might also need to give the Docker engine additional resources (Elasticsearch uses a lot of memory).

***

## Getting started

1. Clone this repo and then enter the directory.
    ```bash
    git clone https://github.com/zacharydhamilton/realtime-log-aggregation
    ```
    ```bash
    cd realtime-log-aggregation
    ```

1. Create Confluent Cloud API Keys if you don't already have them. The documentation to create a Cloud API Key can be found [here](https://docs.confluent.io/cloud/current/access-management/authenticate/api-keys/api-keys.html#create-a-cloud-api-key).
    > **Note:** *This is a **Cloud** API Key, not to be confused with a **Kafka** API Key*.

1. Create a file called `env.sh` to store your Cloud API Key and secret. Replace the placeholder values in the command below. 
    ```bash
    echo "export CONFLUENT_CLOUD_API_KEY="<cloud-key>"\nexport CONFLUENT_CLOUD_API_SECRET="<cloud-secret>"" > env.sh 
    ```

1. Source the variables to the console so they will be set for Terraform. 
    ```bash
    source env.sh
    ```

1. Switch to the Terraform directory.
    ```bash
    cd terraform
    ```

1. Initialize Terraform, plan the configuration, and apply it to create the resources. 
    ```bash
    terraform init
    ```
    ```bash
    terraform plan
    ```
    ```bash
    terraform apply
    ```

1. Once the resources have been created, navigate back to the root directory and source the secrets created by Terraform so they can be used by Docker.
    ```bash
    cd ..
    ```
    ```bash
    source secrets.sh
    ```

1. Now that the secrets about your cluster have been exported to the console, bring the the Docker services online. 
    ```bash
    docker compose up -d
    ```
    > **Note**: *It can be good to double check that the services are all running with: `docker compose ps`.*

1. With the service running, log data should be generating and being written to Kafka. Now, go into the Confluent Cloud UI and navigate to the KsqlDB editor and set the `auto.offset.reset` to `earliest`.

1. Create the first few Ksql queries, `java-app-1`, `java-app-2`.
    ```sql
    CREATE STREAM java_app_1 (
        `@timestamp` DOUBLE,
        `correlationId` VARCHAR,
        `message` VARCHAR,
        `level` VARCHAR,
        `pid` VARCHAR,
        `component` VARCHAR,
        `class` VARCHAR, 
        `container_id` VARCHAR,
        `container_name` VARCHAR,
        `source` VARCHAR
    ) WITH (KAFKA_TOPIC='java-app-1', VALUE_FORMAT='JSON');
    ```
    ```sql
    CREATE STREAM java_app_2 (
        `@timestamp` DOUBLE,
        `correlationId` VARCHAR,
        `message` VARCHAR,
        `level` VARCHAR,
        `pid` VARCHAR,
        `component` VARCHAR,
        `class` VARCHAR, 
        `container_id` VARCHAR,
        `container_name` VARCHAR,
        `source` VARCHAR
    ) WITH (KAFKA_TOPIC='java-app-2', VALUE_FORMAT='JSON');
    ```

1. With the two streams of Java app logs modeled in Ksql, you can join the events from the two streams together by their `correlationId`.
    ```sql
    CREATE STREAM java_apps WITH (KAFKA_TOPIC='java-apps', VALUE_FORMAT='JSON') AS
        SELECT 
            one.`@timestamp` AS `@timestamp`, one.`correlationId`,
            AS_VALUE(one.`correlationId`) AS `correlationId`,
            one.`message` AS `message-one`, two.`message` AS `message-two`,
            one.`level` AS `level-one`, two.`level` AS `level-two`,
            one.`pid` AS `pid-one`, two.`pid` AS `pid-two`,
            one.`component` AS `component-one`, two.`component` AS `component-two`,
            one.`class` AS `class-one`, two.`class` AS `class-two`, 
            one.`container_id` AS `container_id-one`, two.`container_id` AS `container_id-two`,
            one.`container_name` AS `container_name-one`, two.`container_name` AS `container_name-two`,
            one.`source` AS `source-one`, two.`source` AS `source-two`
        FROM java_app_1 one
            JOIN java_app_2 two WITHIN 5 MINUTES 
            ON one.`correlationId` = two.`correlationId` 
        PARTITION BY one.`correlationId`
    EMIT CHANGES;
    ```
1. Next, create a stream for the `logs-raw` events. 
    ```sql 
    CREATE STREAM logs_raw (
        `@timestamp` DOUBLE,
        `team` VARCHAR,
        `contact` VARCHAR,
        `message` VARCHAR,
        `code` VARCHAR,
        `level` VARCHAR,
        `pid` VARCHAR,
        `component` VARCHAR,
        `class` VARCHAR,
        `container_id` VARCHAR,
        `container_name` VARCHAR,
        `source` VARCHAR
    ) WITH (KAFKA_TOPIC='logs-raw', VALUE_FORMAT='JSON');
    ```

1. In order to enrich the `logs_raw` events with additional detail, create the following tables and insert some records into them.
    ```sql 
    CREATE TABLE teams (
        `id` VARCHAR PRIMARY KEY,
        `team` VARCHAR
    ) WITH (KAFKA_TOPIC='teams', VALUE_FORMAT='JSON', PARTITIONS='6');

    INSERT INTO teams (`id`, `team`) VALUES ('1234', 'FrontEnd');
    INSERT INTO teams (`id`, `team`) VALUES ('5678', 'BackEnd');
    ```
    ```sql
    CREATE TABLE contacts (
        `id` VARCHAR PRIMARY KEY,
        `contact` VARCHAR
    ) WITH (KAFKA_TOPIC='contacts', VALUE_FORMAT='JSON', PARTITIONS='6');

    INSERT INTO contacts (`id`, `contact`) VALUES ('u6496', 'Eric MacKay');
    INSERT INTO contacts (`id`, `contact`) VALUES ('u5643', 'Zachary Hamilton');
    INSERT INTO contacts (`id`, `contact`) VALUES ('u6739', 'Steve Jobs');
    INSERT INTO contacts (`id`, `contact`) VALUES ('u3650', 'Bill Gates');
    ```
    ```sql
    CREATE TABLE codes (
        `id` VARCHAR PRIMARY KEY,
        `code` VARCHAR
    ) WITH (KAFKA_TOPIC='codes', VALUE_FORMAT='JSON', PARTITIONS='6');

    -- "Error" level
    INSERT INTO codes (`id`, `code`) VALUES ('5643', 'BrokenTree');
    INSERT INTO codes (`id`, `code`) VALUES ('1325', 'StackUnderflow');
    INSERT INTO codes (`id`, `code`) VALUES ('9797', 'OutOfEnergy');
    INSERT INTO codes (`id`, `code`) VALUES ('4836', 'TooMuchStorage');
    INSERT INTO codes (`id`, `code`) VALUES ('2958', 'RunawayProcess');
    INSERT INTO codes (`id`, `code`) VALUES ('2067', 'TooManyRequests');
    INSERT INTO codes (`id`, `code`) VALUES ('0983', 'SleptTooLong');
    -- "Warn" level
    INSERT INTO codes (`id`, `code`) VALUES ('9476', 'SlowerThanNormal');
    INSERT INTO codes (`id`, `code`) VALUES ('6780', 'ExtraConfigProvided');
    INSERT INTO codes (`id`, `code`) VALUES ('3058', 'DeprecationFlag');
    INSERT INTO codes (`id`, `code`) VALUES ('9853', 'MissingParams');
    -- "Info" level
    INSERT INTO codes (`id`, `code`) VALUES ('0000', 'CompletelyNormalOperation');
    ```

1. Now, with both the raw events and the reference tables created, enrich the events from `logs_raw` by joining them to the reference tables. 
    ```sql
    CREATE STREAM logs_enriched WITH (KAFKA_TOPIC='logs-enriched', VALUE_FORMAT='JSON') AS
        SELECT
            raw.`@timestamp` AS `@timestamp`,
            teams.`team` AS `team`,
            teams.`id` AS `team_id`,
            contacts.`contact` AS `contact`,
            contacts.`id` AS `contact_id`,
            codes.`code` AS `code_detail`,
            codes.`id` AS `code`,
            raw.`message` AS `message`,
            raw.`level` AS `level`,
            raw.`pid` AS `pid`,
            raw.`component` AS `component`,
            raw.`class` AS `class`,
            raw.`container_id` AS `container_id`,
            raw.`container_name` AS `container_name`,
            raw.`source` AS `source` 
        FROM logs_raw raw
            LEFT JOIN teams ON raw.`team` = teams.`id`
            LEFT JOIN contacts ON raw.`contact` = contacts.`id`
            LEFT JOIN codes ON raw.`code` = codes.`id`
        PARTITION BY raw.`container_id`
    EMIT CHANGES;
    ```

1. Next, create a stream from the `events` topic.
    ```sql
    CREATE STREAM events (
        `@timestamp` DOUBLE,
        `message` VARCHAR,
        `level` VARCHAR,
        `pid` VARCHAR, 
        `component` VARCHAR,
        `class` VARCHAR,
        `container_id` VARCHAR,
        `container_name` VARCHAR,
        `source` VARCHAR
    ) WITH (KAFKA_TOPIC='events', VALUE_FORMAT='JSON');
    ```

1. With the `events` stream created, use a windowed aggregation to take the 1 min count of errors every 15 seconds and then create a stream for its changelog.
    ```sql
    CREATE TABLE error_rates WITH (KAFKA_TOPIC='error_rates', VALUE_FORMAT='JSON') AS 
        SELECT 
            `container_id`,
            COUNT(*) AS `errors`,
            COLLECT_SET(`class`) AS `classes`
        FROM events
        WINDOW HOPPING (SIZE 1 MINUTE, ADVANCE BY 15 SECONDS)
        GROUP BY `container_id`
    EMIT FINAL;
    ```
    ```sql 
    CREATE STREAM error_rates_changelog (
        `errors` INT,
        `classes` ARRAY<VARCHAR>
    ) WITH (KAFKA_TOPIC='error_rates', VALUE_FORMAT='JSON');
    ```

1. Finally, create a stream for the `anomalies` topic. Then, create the query to write matching records into it. 
    ```sql
    CREATE STREAM anomalies (
        `@timestamp` DOUBLE,
        `errors` INT,
        `classes` ARRAY<VARCHAR>
    ) WITH (KAFKA_TOPIC='anomalies', VALUE_FORMAT='JSON');
    ```
    ```sql
    INSERT INTO anomalies
        SELECT 
            CAST(ROWTIME AS DOUBLE) AS `@timestamp`,
            `errors`,
            `classes`
        FROM error_rates_changelog
        WHERE `errors` > 12
    EMIT CHANGES;
    ```

1. With the all the Ksql queries created, open Kibana by typing `localhost` into your browser, or clicking [here](http://localhost/).

1. When connected to Kibana, click the left-hand hamburger menu, scroll down, and select "Stack Management". 

1. In the "Stack Management" page, use the left-hand menu to find "Saved Objects", and select it. 

1. In the "Saved Objects" menu, select import. When the import prompt comes up, select the upload option and upload the included saved objects file from this repo. (`./elasticsearch/elasticsearch-saved-objects.ndjson`);

1. With the saved objects uploaded, you should be able to now use the Kibana "Discover" page in order to view the contents of the logs being generated by the Java fake logger, as well as the events output by your Ksql Topology. 

## Cleanup

1. When you're satisfied with your setup and want to throw it away, start by removing the Docker services.
    ```bash
    docker compose down
    ```
    > **Note**: *Make sure you do this from the root directory of the repo, not something else. If you're still in the `terraform/` directory from above, navigate to the root before stopping the services.*

1. When the Docker services have been removed, destroy the resources created by Terraform.
    ```bash
    terraform destroy
    ```
    > **Note**: *As the inverse to the above, make sure you're in the `terraform/` directory before running the command.* 

