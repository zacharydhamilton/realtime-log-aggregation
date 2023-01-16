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

-----------------------------------------------------------------

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

CREATE TABLE teams (
    `id` VARCHAR PRIMARY KEY,
    `team` VARCHAR
) WITH (KAFKA_TOPIC='teams', VALUE_FORMAT='JSON', PARTITIONS='6');

INSERT INTO teams (`id`, `team`) VALUES ('1234', 'FrontEnd');
INSERT INTO teams (`id`, `team`) VALUES ('5678', 'BackEnd');

CREATE TABLE contacts (
    `id` VARCHAR PRIMARY KEY,
    `contact` VARCHAR
) WITH (KAFKA_TOPIC='contacts', VALUE_FORMAT='JSON', PARTITIONS='6');

INSERT INTO contacts (`id`, `contact`) VALUES ('u6496', 'Eric MacKay');
INSERT INTO contacts (`id`, `contact`) VALUES ('u5643', 'Zachary Hamilton');
INSERT INTO contacts (`id`, `contact`) VALUES ('u6739', 'Steve Jobs');
INSERT INTO contacts (`id`, `contact`) VALUES ('u3650', 'Bill Gates');

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

-----------------------------------------------------------------

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

CREATE TABLE error_rates WITH (KAFKA_TOPIC='error_rates', VALUE_FORMAT='JSON') AS 
    SELECT 
        `container_id`,
        COUNT(*) AS `errors`,
        COLLECT_SET(`class`) AS `classes`
    FROM events
    WINDOW HOPPING (SIZE 1 MINUTE, ADVANCE BY 15 SECONDS)
    GROUP BY `container_id`
EMIT FINAL;

CREATE STREAM error_rates_changelog (
    `errors` INT,
    `classes` ARRAY<VARCHAR>
) WITH (KAFKA_TOPIC='error_rates', VALUE_FORMAT='JSON');

CREATE STREAM anomalies (
    `@timestamp` DOUBLE,
    `errors` INT,
    `classes` ARRAY<VARCHAR>
) WITH (KAFKA_TOPIC='anomalies', VALUE_FORMAT='JSON');

INSERT INTO anomalies
    SELECT 
        CAST(ROWTIME AS DOUBLE) AS `@timestamp`,
        `errors`,
        `classes`
    FROM error_rates_changelog
    WHERE `errors` > 12
EMIT CHANGES;
