/*
RAW_VALID_CLAIMS
-Clean, standardize, derive, deduplicate this table to transform and clean the data.
- Create a table claims_clean under curated schema

-- RAW_REJECTED_CLAIMS
-preserve original text/reason/lineage
--create table curated.CLAIMS_REJECTED */

use database healthcare_claim;

create schema if not exists CURATED;
use schema CURATED;

/*
Trim identifiers and codes
Standardize status to uppercase
Retain typed dates and amounts
Derive claim_month
Preserve filename and load timestamp
Use ROW_NUMBER() to keep the latest row per claim_id */

create or replace table  HEALTHCARE_CLAIM.CURATED.CLAIMS_CLEAN
as
select
trim(claim_id) as claim_id,
member_id::int as member_id,
trim(provider_id) as provider_id,
trim(diagnosis_code) as diagnosis_code,
service_date::date as service_date,
date_trunc('month',service_date) as claim_month,
claim_amount,
upper(trim(claim_status)) as claim_status,
source_filename,
load_timestamp
from HEALTHCARE_CLAIM.RAW.RAW_VALID_CLAIMS
where claim_id is not null
  and trim(claim_id) <> ''
qualify(row_number() over(partition by trim(claim_id) order by load_timestamp desc,source_filename)) = 1;

/*
Source: RAW.RAW_REJECTED_CLAIMS
Preserve all rejected source columns.
Preserve rejection_reason.
Preserve source_filename and load_timestamp.
Keep invalid member IDs, dates, and amounts as text.
Do not trim, standardize, cast, derive, or deduplicate rejected values.
Make the build safely rerunnable without appending.
 */

create or replace table curated.claims_rejected
as
 select
 claim_id,
 member_id,
 provider_id,
 diagnosis_code,
 service_date ,
 claim_amount,
 claim_status,
 rejection_reason,
 source_filename,
 load_timestamp
 from raw.raw_rejected_claims;

 --validation queries
    select
    count(*) as clean_row_count,
    (
        select
            count(*)
        from
            claims_rejected
    ) as rejected_row_count,
    (
        select
            count(*)
        from
            (
                select
                    count(*) as count
                from
                    claims_clean
                group by
                    claim_id
                having
                    count(*) > 1
            )
    ) as duplicate_claim_id_count,
    count_if(
        claim_id is null
        or member_id is null
        or trim(claim_id) = ''
        or provider_id is null
        or trim(provider_id) = ''
        or service_date is null
        or claim_amount is null
        or claim_status is null
        or trim(claim_status) = ''
    ) as missing_mandatory_count,
    count_if(claim_amount <= 0) as non_positive_amount_count,
    count_if(
        claim_status not in ('APPROVED', 'DENIED', 'PENDING')
    ) as invalid_status_count
from
    claims_clean;

--Grain-> service_date would be the grain of this claim summary where all the calculation would be
--done for each service date.
--Measures-> Six required measures value would be
                --Total claim count
                --Total claim amount
                -- Approved claim count
                -- Denied claim count
                --Pending claim count
                --Approved claim amount
-- Consumer and decision-> This will be required for business decisions where a claims manager can identify days with unusually high denied or pending claim volumes.

create or replace table curated.DAILY_CLAIM_SUMMARY
as
select
service_date,
count(*) as total_claim_count,
sum(claim_amount) as total_claim_amount,
count_if(claim_status = 'APPROVED') as approved_claim_count,
count_if(claim_status = 'DENIED') as denied_claim_count,
count_if(claim_status = 'PENDING') as pending_claim_count,
sum(iff(claim_status = 'APPROVED',claim_amount,0)) as approved_claim_amount
from claims_clean
group by service_date
order by service_date;

select *
from daily_claim_summary
order by service_date;

--Data reconciliation between daily summary and clean rows

with daily_summary as
(
    select
        count(*) as summary_row_count,
        sum(total_claim_count) as total_claim_count_sum,
        sum(total_claim_amount) as total_claim_amount,
        sum(APPROVED_CLAIM_COUNT+DENIED_CLAIM_COUNT+PENDING_CLAIM_COUNT) as summed_status_count
    from daily_claim_summary
),

claims_clean_summary as
(
    select
        count(distinct service_date) as total_clean_date_count,
        count(*) as total_clean_row_count,
        sum(claim_amount) as total_clean_claim_amounts
    from claims_clean
)

select
    s.summary_row_count,
    c.total_clean_date_count,
    s.total_claim_count_sum,
    c.total_clean_row_count as clean_count_for_claim_reconciliation,
    s.total_claim_amount,
    c.total_clean_claim_amounts,
    s.summed_status_count,
    c.total_clean_row_count as clean_count_for_status_reconciliation
from daily_summary s,claims_clean_summary c;
