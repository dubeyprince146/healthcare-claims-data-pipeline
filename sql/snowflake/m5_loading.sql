--S3 landing
--The requirement is to fetch the data from S3 and load to the snowflake tables
-- Storage integration allows Snowflake to access S3 through an IAM role without AWS access keys.
--external stage-> it is storage location used outside of snowflake to store the files before or after loading or unloading.
--raw tables--> Raw table will consist raw data directly coming from source csv file.
--load audit--> it records file-loading details such as filename, load time, row counts, and load status.

/*
 chosen names for:-
 -Database -- healthcare_claim
- RAW schema -- RAW
- AUDIT schema --AUDIT
- Warehouse -- healthcare_compute
- CSV file format --CSV_FILE_FORMAT
- Storage integration-- s3_sf_healthcare_int
- External stage-- S3_LANDING_STAGE
-Table names: Raw tables for valid_claim.csv- > RAW_VALID_CLAIMS
              Raw tables for rejected_claim.csv--> RAW_REJECTED_CLAIMS
              Audit table for auditing --> FILE_LOAD_AUDIT
*/
Create database healthcare_claim;
--DATABASE
use database healthcare_claim;
--SCHEMA
create schema RAW;
create schema AUDIT;

use schema RAW;


--WAREHOUSE
create or replace warehouse healthcare_compute
    WAREHOUSE_TYPE = 'STANDARD'
    warehouse_size = 'XSMALL'
    AUTO_SUSPEND = 300
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = TRUE;
--FILE_FORMAT
CREATE OR REPLACE FILE FORMAT CSV_FILE_FORMAT
TYPE = 'CSV'
COMPRESSION = AUTO
SKIP_HEADER = 1
EMPTY_FIELD_AS_NULL = TRUE
FIELD_DELIMITER = ','
FIELD_OPTIONALLY_ENCLOSED_BY = '"'
ENCODING = 'UTF8';

--Storage integration setting

create storage integration S3_SF_HEALTHCARE_INT
TYPE = EXTERNAL_STAGE
STORAGE_PROVIDER = 'S3'
ENABLED = TRUE
STORAGE_AWS_ROLE_ARN = '<SNOWFLAKE_S3_ROLE_ARN>'
STORAGE_ALLOWED_LOCATIONS = ('s3://healthcare-claims-pipeline-dev-s3/landing/');

DESC INTEGRATION S3_SF_HEALTHCARE_INT;

SHOW FILE FORMATS LIKE 'CSV_FILE_FORMAT' IN DATABASE HEALTHCARE_CLAIM;

--Stage creation

CREATE STAGE S3_Landing_Stage
FILE_FORMAT = (FORMAT_NAME = 'CSV_FILE_FORMAT')
URL = 's3://healthcare-claims-pipeline-dev-s3/landing/'
STORAGE_INTEGRATION = S3_SF_HEALTHCARE_INT;

list @S3_landing_stage;

SHOW WAREHOUSES LIKE 'HEALTHCARE_COMPUTE'
  ->> SELECT
          "name",
          "state",
          "type",
          "size",
          "auto_suspend",
          "auto_resume"
      FROM $1;


-- TABLE CREATION
CREATE  TABLE IF NOT EXISTS HEALTHCARE_CLAIM.RAW.RAW_VALID_CLAIMS
(
claim_id VARCHAR(10) NOT NULL,
member_id INTEGER,
provider_id VARCHAR(10),
diagnosis_code VARCHAR(20),
service_date DATE,
claim_amount NUMBER(12,2),
claim_status VARCHAR,
source_filename VARCHAR,
load_timestamp timestamp_ltz default current_timestamp()
);

CREATE  TABLE IF NOT EXISTS HEALTHCARE_CLAIM.RAW.RAW_REJECTED_CLAIMS
(
claim_id VARCHAR(10),
member_id VARCHAR,
provider_id VARCHAR(10),
diagnosis_code VARCHAR(20),
service_date VARCHAR,
claim_amount VARCHAR,
claim_status VARCHAR,
rejection_reason VARCHAR,
source_filename VARCHAR,
load_timestamp timestamp_ltz default current_timestamp()
);

show tables
->> SELECT
        "name",
        "schema_name",
        "kind",
        "rows"
        from $1;

--CREATING Audit table
CREATE TABLE IF NOT EXISTS HEALTHCARE_CLAIM.AUDIT.FILE_LOAD_AUDIT
(
    audit_id NUMBER AUTOINCREMENT START 1 INCREMENT 1 ORDER,
    file_name VARCHAR,
    target_table VARCHAR,
    load_time TIMESTAMP_LTZ,
    row_count NUMBER,
    status VARCHAR,
    audit_recorded_at TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP()
);
SHOW TABLES LIKE 'FILE_LOAD_AUDIT'
IN SCHEMA HEALTHCARE_CLAIM.AUDIT;

---COPY INTO COMMAND

COPY INTO HEALTHCARE_CLAIM.RAW.RAW_VALID_CLAIMS
(claim_id,member_id,provider_id,diagnosis_code,service_date,claim_amount,claim_status,source_filename,load_timestamp)
from
    (select
    $1 as claim_id,
    $2 as member_id,
    $3 as provider_id,
    $4 as diagnosis_code,
    $5 as service_date,
    $6 as claim_amount,
    $7 as claim_status,
    METADATA$FILENAME as source_filename,
    METADATA$START_SCAN_TIME as load_timestamp
    from @S3_LANDING_STAGE/validated/
    )
    PATTERN = '.*valid_claims[.]csv'
    FILE_FORMAT = (FORMAT_NAME = 'CSV_FILE_FORMAT')
    FORCE = FALSE;

SELECT COUNT(*) AS valid_count
FROM HEALTHCARE_CLAIM.RAW.RAW_VALID_CLAIMS;
--valid_count = 10
COPY INTO HEALTHCARE_CLAIM.RAW.RAW_REJECTED_CLAIMS
(claim_id,member_id,provider_id,diagnosis_code,service_date,claim_amount,claim_status,rejection_reason,source_filename,load_timestamp)
from
    (select
    $1 as claim_id,
    $2 as member_id,
    $3 as provider_id,
    $4 as diagnosis_code,
    $5 as service_date,
    $6 as claim_amount,
    $7 as claim_status,
    $8 as rejection_reason,
    METADATA$FILENAME as source_filename,
    METADATA$START_SCAN_TIME as load_timestamp
    from @S3_LANDING_STAGE/rejected/
    )
    PATTERN = '.*rejected_claims[.]csv'
    FILE_FORMAT = (FORMAT_NAME = 'CSV_FILE_FORMAT')
    FORCE = FALSE;

    SELECT
    (SELECT COUNT(*) FROM HEALTHCARE_CLAIM.RAW.RAW_VALID_CLAIMS) AS valid_count,
    (SELECT COUNT(*) FROM HEALTHCARE_CLAIM.RAW.RAW_REJECTED_CLAIMS) AS rejected_count;

    --copy history
    select FILE_NAME,
    TABLE_NAME,
    LAST_LOAD_TIME,
    ROW_COUNT,
    STATUS
    from table(healthcare_claim.information_schema.copy_history
                        (TABLE_NAME => 'HEALTHCARE_CLAIM.RAW.RAW_VALID_CLAIMS',
                        START_TIME => dateadd('hour',-24,current_timestamp()) ))
    union all
    select FILE_NAME,
    TABLE_NAME,
    LAST_LOAD_TIME,
    ROW_COUNT,
    STATUS
    from table(healthcare_claim.information_schema.copy_history
                        (TABLE_NAME => 'HEALTHCARE_CLAIM.RAW.RAW_REJECTED_CLAIMS',
                        START_TIME => dateadd('hour',-24,current_timestamp()) ))
                        order by LAST_LOAD_TIME desc;

--data insertion in audit table
INSERT into HEALTHCARE_CLAIM.AUDIT.FILE_LOAD_AUDIT
(file_name,
target_table,
load_time,
row_count,
status)
Select
hst.FILE_NAME,
hst.TABLE_NAME,
hst.LAST_LOAD_TIME,
hst.ROW_COUNT,
hst.STATUS
from
(select FILE_NAME,
    TABLE_NAME,
    LAST_LOAD_TIME,
    ROW_COUNT,
    STATUS
    from table(healthcare_claim.information_schema.copy_history
                        (TABLE_NAME => 'HEALTHCARE_CLAIM.RAW.RAW_VALID_CLAIMS',
                        START_TIME => dateadd('hour',-24,current_timestamp()) ))
    union all
    select FILE_NAME,
    TABLE_NAME,
    LAST_LOAD_TIME,
    ROW_COUNT,
    STATUS
    from table(healthcare_claim.information_schema.copy_history
                        (TABLE_NAME => 'HEALTHCARE_CLAIM.RAW.RAW_REJECTED_CLAIMS',
                        START_TIME => dateadd('hour',-24,current_timestamp()) ))
                        ) as hst
                        where NOT EXISTS (
                            select 1
                            from healthcare_claim.audit.file_load_audit as audit
                            where
                            audit.file_name = hst.file_name
                            and audit.target_table = hst.table_name
                            and audit.load_time = hst.last_load_time
                        );
select
audit_id,
file_name,
target_table,
load_time,
row_count,
status,
audit_recorded_at
from healthcare_claim.audit.file_load_audit
order by audit_id;
