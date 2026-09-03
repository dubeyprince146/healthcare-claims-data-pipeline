# Healthcare Claims Data Pipeline

## Project Overview and Current Status

This project implements a foundation data pipeline for processing synthetic healthcare claims. Python validates the source records and separates them into valid and rejected datasets. The resulting files are stored in a private AWS S3 landing area and securely loaded into Snowflake, where they are audited, transformed into curated tables, summarized by service date, and reconciled against the clean claim data.

Milestones M1–M6 are complete, covering repository setup, data definition and analysis, Python validation, secure S3 storage, Snowflake loading and auditing, and curated transformations. M7 — Documentation and Review is currently active. The foundation pipeline is implemented, but the overall project is not yet complete.

## Architecture and Implemented Data Flow

The pipeline follows separate valid and rejected data paths:

```text
Synthetic claims CSV
        ↓
Python validation
        ├── Valid records → valid_claims.csv
        └── Rejected records → rejected_claims.csv with rejection reasons
        ↓
Private AWS S3 landing area
        ├── landing/source/
        ├── landing/validated/
        └── landing/rejected/
        ↓
Snowflake storage integration and external stage
        ├── Validated files → RAW.RAW_VALID_CLAIMS
        ├── Rejected files → RAW.RAW_REJECTED_CLAIMS
        └── COPY/load history → AUDIT.FILE_LOAD_AUDIT

Implemented transformation paths
        ├── RAW.RAW_VALID_CLAIMS
        │       ↓
        │   CURATED.CLAIMS_CLEAN
        │       ↓
        │   CURATED.DAILY_CLAIM_SUMMARY and reconciliation checks
        └── RAW.RAW_REJECTED_CLAIMS
                ↓
            CURATED.CLAIMS_REJECTED
```

The valid path produces typed, standardized, and deduplicated claim records for analysis. The rejected path preserves invalid source values, rejection reasons, filenames, and load timestamps for investigation. Snowflake accesses the private S3 landing area through an IAM role and storage integration without committed AWS access keys.

## Repository Structure

```text
healthcare-claims-data-pipeline/
├── data/
│   ├── input/
│   │   └── claims_20260803.csv
│   └── output/
│       ├── valid_claims.csv
│       └── rejected_claims.csv
├── docs/
│   └── data_dictionary.md
├── logs/
│   └── validation.log              # Runtime file; ignored by Git
├── sql/
│   ├── practice/
│   │   ├── day02_month_over_month_claims.sql
│   │   └── highest_approved_claim.sql
│   └── snowflake/
│       ├── m5_loading.sql
│       └── m6_transformations.sql
├── src/
│   ├── claim_summary.py
│   ├── practice/
│   │   └── day02_claim_analysis.py
│   └── validation/
│       └── validate_claims.py
├── .gitignore
├── README.md
└── requirements.txt
```

- `data/input/` contains the synthetic source claims file.

- `data/output/` contains the valid and rejected files produced by Python validation.

- `docs/` contains the claims data dictionary.

- `logs/` receives runtime validation logs, which are excluded from Git.

- `sql/practice/` contains SQL learning exercises.

- `sql/snowflake/` contains the Snowflake loading, audit, transformation, summary, and reconciliation SQL.

- `src/practice/` contains Python learning exercises.

- `src/validation/` contains the claims validation script.

## Prerequisites and Local Setup

### Prerequisites

The following tools and accounts are required:

- Python 3
- Git
- An AWS account with access to the project’s private S3 bucket
- A Snowflake account with permission to use the project database, schemas, warehouse, storage integration, and external stage
- A code editor such as Visual Studio Code

### Local Setup

From the project root, create a Python virtual environment:

```bash
python3 -m venv .venv
```

Activate it on macOS or Linux:

```bash
source .venv/bin/activate
```

Confirm that Python is available:

```bash
python3 --version
```

The claims validator uses only the Python standard library, including `csv`, `datetime`, `decimal`, `logging`, `pathlib`, and `collections`. No third-party Python packages are currently required. Therefore, `requirements.txt` is intentionally empty.

The `.venv/` directory is excluded from Git and should be created separately in each local development environment.

## Dataset and Python Validation

### Input Dataset

The pipeline uses `data/input/claims_20260803.csv`, which contains 15 synthetic healthcare claim records. The dataset was created only for learning, development, and pipeline testing. It does not contain real patient or healthcare information.

Field definitions and validation expectations are documented in the [data dictionary](docs/data_dictionary.md).

### Dataset Fields

| Field | Business meaning | Required |
|---|---|---|
| `claim_id` | Unique identifier assigned to a claim | Yes |
| `member_id` | Identifier of the member associated with the claim | Yes |
| `provider_id` | Identifier of the healthcare provider associated with the claim | Yes |
| `diagnosis_code` | Code representing the diagnosis related to the claim | No |
| `service_date` | Calendar date on which the healthcare service was provided | Yes |
| `claim_amount` | Monetary amount submitted for the claim | Yes |
| `claim_status` | Processing status of the claim: `APPROVED`, `DENIED`, or `PENDING` | Yes |

### Python Validation

The validation script checks that all seven expected columns exist and that mandatory values are populated. It also validates member IDs as integers, service dates as real calendar dates in `YYYY-MM-DD` format, claim amounts as numeric values greater than zero, and claim statuses against the allowed values.

The test dataset contains one rejected record in each of these five categories:

- Missing mandatory value
- Non-positive claim amount
- Invalid claim status
- Duplicate `claim_id`, where only a later occurrence is rejected
- Invalid service date

The validator retains all applicable rejection reasons for a row instead of stopping after the first failed validation.

From the project root, execute the validator with:

```bash
python3 src/validation/validate_claims.py
```

### Validation Outputs

The validator writes records without rejection reasons to:

```text
data/output/valid_claims.csv
```

Records with one or more rejection reasons are written to:

```text
data/output/rejected_claims.csv
```

The rejected output includes an additional `rejection_reason` column.

The verified results are:

| Result | Count |
|---|---:|
| Input rows | 15 |
| Valid rows | 10 |
| Rejected rows | 5 |

### Runtime Logging

Runtime validation information is written to:

```text
logs/validation.log
```

The log records the validation start and completion, input filename, total rows processed, valid and rejected row counts, and counts for each expected rejection category.

Runtime log files are excluded from Git by the `logs/*.log` rule in `.gitignore`. The log is generated locally when the validator runs and should not be committed.

## AWS S3 and Security Configuration

### Private Landing Area

The pipeline uses a private AWS S3 landing area with three prefixes:

- `landing/source/` stores the original synthetic source files.
- `landing/validated/` stores records that passed Python validation.
- `landing/rejected/` stores rejected records and their validation reasons.

Only synthetic project data belongs in these locations. Runtime logs, environment files, credentials, and real healthcare data must not be uploaded.

### Bucket Security Controls

The S3 bucket is configured as a private storage location. All Block Public Access settings are enabled, preventing objects from being exposed publicly. ACLs are disabled, and Object Ownership is configured as Bucket owner enforced so that access is managed through IAM policies instead of object-level ACLs.

Default encryption is enabled using Amazon S3-managed server-side encryption keys (SSE-S3). IAM permissions follow least-privilege principles and limit project access to the required bucket operations and objects under the `landing/` prefix.

### IAM User and Snowflake IAM Role

The IAM user is intended for authorized manual AWS Console work, such as uploading and verifying the project’s synthetic files. It represents a human user and is not used by Snowflake.

The IAM role is intended for Snowflake and is not attached to the human IAM user. Snowflake assumes this role through the configured storage integration to read files from the private landing area. The role grants only the bucket-listing, bucket-location, and object-read permissions required for the `landing/` path.

This separation allows manual work and system-to-system access to have different permissions. Snowflake can use temporary role-based access instead of relying on long-term AWS access keys.

### Snowflake Storage Integration and External Stage

The Snowflake storage integration is enabled and restricted to the project’s S3 `landing/` location. AWS trusts the Snowflake-generated principal through the IAM role’s trust policy.

The external stage references the storage integration and private landing path. This allows Snowflake to list and load the source, validated, and rejected files without embedding AWS credentials in SQL files.

### Repository Security Rules

The repository must never contain:

- AWS credentials or access keys
- AWS account identifiers
- Private IAM role ARNs
- Snowflake storage-integration external IDs
- Passwords, tokens, or environment secrets
- Real healthcare, patient, or protected health information

SQL committed to Git uses placeholders where private cloud identifiers would otherwise be required. Only synthetic data and non-sensitive configuration descriptions are stored in the repository.

## Snowflake Loading, Audit, and Transformations

### Snowflake Foundation

The Snowflake foundation uses the following objects:

| Object type | Object name | Purpose |
|---|---|---|
| Database | `HEALTHCARE_CLAIM` | Contains the pipeline’s Snowflake objects |
| Raw schema | `HEALTHCARE_CLAIM.RAW` | Stores claim records loaded from S3 |
| Audit schema | `HEALTHCARE_CLAIM.AUDIT` | Stores file-load audit information |
| Warehouse | `HEALTHCARE_COMPUTE` | X-Small standard warehouse used for loading and SQL processing |
| CSV file format | `CSV_FILE_FORMAT` | Defines how claim CSV files are interpreted |
| Storage integration | `S3_SF_HEALTHCARE_INT` | Provides role-based access to the private S3 landing area |
| External stage | `S3_LANDING_STAGE` | Makes the permitted S3 landing files available to Snowflake |

The warehouse is configured with automatic resume and a 300-second automatic suspension period to reduce unnecessary compute usage. The named CSV file format skips the header row and treats empty fields consistently as null values.

### Raw Tables and Loading Sequence

The loading process uses two raw tables:

- `HEALTHCARE_CLAIM.RAW.RAW_VALID_CLAIMS` receives records from `valid_claims.csv`.
- `HEALTHCARE_CLAIM.RAW.RAW_REJECTED_CLAIMS` receives records from `rejected_claims.csv`, including the `rejection_reason` field.

The loading sequence is:

1. Snowflake accesses the private S3 landing area through `S3_SF_HEALTHCARE_INT`.
2. `S3_LANDING_STAGE` lists the files available under the permitted landing path.
3. The named CSV file format interprets the staged CSV records.
4. Validated records are copied into `RAW_VALID_CLAIMS`.
5. Rejected records are copied into `RAW_REJECTED_CLAIMS`.
6. Snowflake COPY history is used to record the load results in `HEALTHCARE_CLAIM.AUDIT.FILE_LOAD_AUDIT`.

Both raw tables preserve lineage through:

- `source_filename`, which identifies the staged file that supplied the record.
- `load_timestamp`, which records when Snowflake scanned the file during loading.

The verified load results are:

| Raw table | Loaded rows |
|---|---:|
| `RAW_VALID_CLAIMS` | 10 |
| `RAW_REJECTED_CLAIMS` | 5 |

### COPY History and Load Audit

Snowflake COPY history records the filename, target table, load time, row count, and load status. Two successful load records were captured:

- One record for the validated file loaded into `RAW_VALID_CLAIMS` with 10 rows.
- One record for the rejected file loaded into `RAW_REJECTED_CLAIMS` with 5 rows.

These two records were inserted into `HEALTHCARE_CLAIM.AUDIT.FILE_LOAD_AUDIT`. The audit insertion checks whether the same filename, target table, and load timestamp already exist before adding a record, preventing the same COPY-history event from being recorded more than once.

### Duplicate-File Protection and Limitation

The COPY commands use `FORCE = FALSE`. When the same unchanged staged files are processed again, Snowflake uses its load history to skip files that were already loaded. The rerun loaded zero additional rows, and the raw-table counts remained 10 valid and 5 rejected records.

This protection is based on staged filenames and Snowflake load history. It is not business-key or content-level idempotency. If equivalent claim data arrives under a different filename, the file may be treated as new and loaded again. Additional business-key or content-based controls would be required to detect that situation.

### Curated Transformations

The `HEALTHCARE_CLAIM.CURATED` schema contains the transformed analytical tables:

- `HEALTHCARE_CLAIM.CURATED.CLAIMS_CLEAN`
- `HEALTHCARE_CLAIM.CURATED.CLAIMS_REJECTED`
- `HEALTHCARE_CLAIM.CURATED.DAILY_CLAIM_SUMMARY`

`CLAIMS_CLEAN` represents the typed clean-data boundary. Member IDs, service dates, and claim amounts retain appropriate Snowflake data types for analysis. Claim identifiers, provider identifiers, and diagnosis codes are trimmed, while claim statuses are trimmed and standardized to uppercase. The transformation also derives `claim_month` from `service_date`.

`CLAIMS_REJECTED` preserves the invalid source values as text so that malformed member IDs, dates, and amounts are not lost or altered through casting. It also retains `rejection_reason`, `source_filename`, and `load_timestamp` for investigation and lineage tracking.

Both curated claim tables preserve the source filename and load timestamp from the raw layer.

### Clean-Claim Deduplication

The clean transformation applies a deterministic deduplication rule to the normalized `claim_id`. Rows are ranked within each trimmed claim identifier, with the most recent `load_timestamp` ranked first. `source_filename` provides an additional ordering rule when load timestamps are equal, and only the first-ranked row is retained.

Blank or null claim identifiers are excluded from the clean table. This produces one current clean record per claim identifier.

### Daily Claims Summary

`CURATED.DAILY_CLAIM_SUMMARY` has a grain of one row per `service_date`. It contains six measures:

- Total claim count
- Total claim amount
- Approved claim count
- Denied claim count
- Pending claim count
- Approved claim amount

This daily view allows claims managers and analysts to monitor claim volumes, financial totals, and status patterns by service date.

### Rerunnable Transformations

The curated tables are built with replace-based table creation. Rerunning the transformation rebuilds each table from the current raw data instead of appending another copy of the existing curated rows. This supports repeatable development runs while keeping the curated outputs aligned with their raw sources.

### Curated Validation Results

The verified curated results are:

| Validation | Result |
|---|---:|
| Clean rows | 10 |
| Rejected rows | 5 |
| Duplicate clean claim IDs | 0 |
| Missing mandatory values | 0 |
| Non-positive claim amounts | 0 |
| Invalid claim statuses | 0 |

### Daily Summary Reconciliation

The daily summary was reconciled against `CLAIMS_CLEAN` to confirm that aggregation did not lose or duplicate data:

| Reconciliation check | Daily summary | Clean data |
|---|---:|---:|
| Summary rows versus distinct service dates | 10 | 10 |
| Summed daily claim count versus clean claim count | 10 | 10 |
| Summed daily claim amount versus clean claim amount | 68000.00 | 68000.00 |
| Summed status counts versus clean claim count | 10 | 10 |

All four reconciliation checks matched.

## End-to-End Run Order and Current Limitations

### Run Order

1. Run the [claims validation script](src/validation/validate_claims.py) from the project root:

   ```bash
   python3 src/validation/validate_claims.py
   ```

2. Review the generated files in `data/output/` and confirm the validation summary in `logs/validation.log`.

3. Manually upload the synthetic source, valid, and rejected files to their corresponding S3 locations:

   - `landing/source/2026/08/03/claims_20260803.csv`
   - `landing/validated/2026/08/03/valid_claims.csv`
   - `landing/rejected/2026/08/03/rejected_claims.csv`

4. Review [m5_loading.sql](sql/snowflake/m5_loading.sql) and execute its applicable foundation, integration, staging, loading, audit, and verification sections in order. Supply the real IAM-role value only in the private Snowflake worksheet; never save or commit that private value to Git. The file contains manually executed sections and should not be treated as a fully idempotent, one-shot deployment script.

5. Use [m6_transformations.sql](sql/snowflake/m6_transformations.sql) to build the clean and rejected curated tables.

6. Continue with the same transformation script to create the daily claims summary.

7. Run the quality and reconciliation queries in the transformation script and confirm the expected clean, rejected, summary, amount, and status totals.

### Current Limitations

- Local validation and S3 uploads are manually executed.
- The pipeline currently processes one small synthetic file in one CSV source format.
- No orchestration, scheduling, alerting, or automatic retry mechanism has been implemented.
- No automated unit or integration tests have been added.
- Snowflake’s filename and load-history protection does not provide content-level or business-key idempotency.
- Clean-table deduplication selects one current curated row per `claim_id`, but it does not prevent duplicate records from entering the raw layer.
- Real healthcare, patient, or protected health information is not permitted in this project.
