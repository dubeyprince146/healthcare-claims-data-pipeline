# Healthcare Claims Pipeline Architecture

This diagram shows the implemented M1–M6 foundation pipeline, including local validation, private S3 landing, Snowflake loading, auditing, curated transformations, and daily reconciliation.

```mermaid
flowchart TB

    subgraph LOCAL["Local / Python"]
        direction LR
        SOURCE["data/input/<br/>claims_20260803.csv"]
        VALIDATOR["src/validation/<br/>validate_claims.py"]
        VALID_FILE["data/output/<br/>valid_claims.csv"]
        REJECTED_FILE["data/output/<br/>rejected_claims.csv"]

        SOURCE --> VALIDATOR
        VALIDATOR -->|Valid records| VALID_FILE
        VALIDATOR -->|Rejected records and reasons| REJECTED_FILE
    end

    subgraph AWS["AWS S3"]
        direction LR
        IAM_USER["IAM user<br/>Manual console work only"]
        BUCKET_SECURITY["Private bucket controls<br/>Block Public Access<br/>ACLs disabled<br/>Bucket owner enforced<br/>SSE-S3"]
        S3_SOURCE["landing/source/"]
        S3_VALID["landing/validated/"]
        S3_REJECTED["landing/rejected/"]
        SF_ROLE["Dedicated Snowflake IAM role"]

        IAM_USER -.->|Authorized manual access| BUCKET_SECURITY
        SF_ROLE -.->|Least-privilege read access to landing/| BUCKET_SECURITY
    end

    subgraph SNOWFLAKE["Snowflake — HEALTHCARE_CLAIM"]
        direction TB

        INTEGRATION["S3_SF_HEALTHCARE_INT"]
        STAGE["S3_LANDING_STAGE"]
        FILE_FORMAT["CSV_FILE_FORMAT"]
        WAREHOUSE["HEALTHCARE_COMPUTE<br/>X-Small warehouse"]

        COPY_VALID["COPY INTO valid raw table<br/>FORCE = FALSE"]
        COPY_REJECTED["COPY INTO rejected raw table<br/>FORCE = FALSE"]

        RAW_VALID["RAW.RAW_VALID_CLAIMS"]
        RAW_REJECTED["RAW.RAW_REJECTED_CLAIMS"]

        COPY_HISTORY["Snowflake COPY history"]
        LOAD_AUDIT["AUDIT.FILE_LOAD_AUDIT"]

        CLEAN["CURATED.CLAIMS_CLEAN"]
        CURATED_REJECTED["CURATED.CLAIMS_REJECTED"]
        DAILY["CURATED.DAILY_CLAIM_SUMMARY"]
        CHECKS["Quality and reconciliation checks"]

        STAGE -.->|Uses| INTEGRATION
        INTEGRATION -.->|Assumes| SF_ROLE

        STAGE -->|Validated file| COPY_VALID
        STAGE -->|Rejected file| COPY_REJECTED

        FILE_FORMAT -.->|Parses CSV| COPY_VALID
        FILE_FORMAT -.->|Parses CSV| COPY_REJECTED
        WAREHOUSE -.->|Executes| COPY_VALID
        WAREHOUSE -.->|Executes| COPY_REJECTED

        COPY_VALID --> RAW_VALID
        COPY_REJECTED --> RAW_REJECTED

        COPY_VALID ==>|Load event| COPY_HISTORY
        COPY_REJECTED ==>|Load event| COPY_HISTORY
        COPY_HISTORY ==>|Audit record| LOAD_AUDIT

        RAW_VALID --> CLEAN
        RAW_REJECTED --> CURATED_REJECTED
        CLEAN --> DAILY
        CLEAN --> CHECKS
        DAILY --> CHECKS
        CURATED_REJECTED --> CHECKS
    end

    SOURCE -->|Manual source upload| S3_SOURCE
    VALID_FILE -->|Manual valid upload| S3_VALID
    REJECTED_FILE -->|Manual rejected upload| S3_REJECTED

    S3_SOURCE -->|Visible through LIST| STAGE
    S3_VALID -->|Available to stage| STAGE
    S3_REJECTED -->|Available to stage| STAGE

    subgraph LEGEND["Legend"]
        direction LR
        VALID_LEGEND["Valid path"] --> VALID_LINE["Solid data flow"]
        REJECTED_LEGEND["Rejected path"] --> REJECTED_LINE["Solid data flow"]
        AUDIT_LEGEND["Audit path"] ==> AUDIT_LINE["Thick evidence flow"]
        SECURITY_LEGEND["Security / control"] -.-> SECURITY_LINE["Dotted relationship"]
    end

    classDef valid fill:#dcfce7,stroke:#15803d,color:#14532d;
    classDef rejected fill:#ffedd5,stroke:#c2410c,color:#7c2d12;
    classDef audit fill:#dbeafe,stroke:#1d4ed8,color:#1e3a8a;
    classDef security fill:#f3f4f6,stroke:#4b5563,color:#111827;
    classDef neutral fill:#ffffff,stroke:#64748b,color:#0f172a;

    class VALID_FILE,S3_VALID,COPY_VALID,RAW_VALID,CLEAN,DAILY,CHECKS,VALID_LEGEND,VALID_LINE valid;
    class REJECTED_FILE,S3_REJECTED,COPY_REJECTED,RAW_REJECTED,CURATED_REJECTED,REJECTED_LEGEND,REJECTED_LINE rejected;
    class COPY_HISTORY,LOAD_AUDIT,AUDIT_LEGEND,AUDIT_LINE audit;
    class IAM_USER,BUCKET_SECURITY,SF_ROLE,INTEGRATION,SECURITY_LEGEND,SECURITY_LINE security;
    class SOURCE,VALIDATOR,S3_SOURCE,STAGE,FILE_FORMAT,WAREHOUSE neutral;
```
