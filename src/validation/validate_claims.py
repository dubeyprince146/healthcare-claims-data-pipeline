#define the expected and mandatory columns
    #Expected columns
        #claim_id
        #member_id
        #provider_id
        #diagnosis_code
        #service_date
        #claim_amount
        #claim_status
    #Mandatory Columns
        #All Except diagnosis_code

#Open the CSV file and read all the Headers.
#header validation rule
    #compare the CSV header with all seven expected columns.
    #stop processing and log an error “if expected columns are missing,” because all seven columns
    # must exist even though diagnosis_code may contain an empty value.
#Validate all the below conditions for each row.
    #Mandatory values cannot be empty.
    #Claim amount must be numeric and positive.
    #claim status must be either of APPROVED, DENIED, PENDING.
    #Service date format must be in YYYY-MM-DD and it should be a valid date as per calendar.
    #Claim_id must be unique.
    #Member Id must be a valid integer.

#Duplicate Handling
    #First occurrence of nonblank claim_id is not rejected as duplicate.
    #Every later occurrence is rejected.
    #Add the first nonblank claim id to the collection of seen IDs.
    #if that ID appears later , add a duplicate reason.
    #Do not add a blank claim id to the seen id collection.

#Log three counts: Total, valid and rejected.

#Rejection- Reason handling
    #Create an empty rejection list for each row
    #add every failed validation reason to that list
    #do not stop after the first failure.
#output
    #rows without rejection reason go to valid_claims.csv
    #rows with rejection reasons go to rejected_claims.csv
    #Write the rejection_reason column to rejected rows.

import csv
import logging
from collections import Counter
from datetime import datetime
from decimal import Decimal
from decimal import InvalidOperation
from pathlib import Path

def validate_headers(actual_columns, expected_columns):
    actual_columns = set(actual_columns or [])
    expected_headers = set(expected_columns)
    missing_columns = expected_headers - actual_columns
    #stop when headers are missing
    if missing_columns:
        error_message = f"CSV header validation failed. Missing_columns are: {sorted(missing_columns)}"
        logging.error(error_message)
        raise ValueError(error_message)

def validate_row(row, mandatory_columns, allowed_statuses, seen_claim_ids, rejection_counts):
    rejection_reasons = []
    for column in mandatory_columns:
        #Missing Mandatory Value Check
        value = (row.get(column) or "").strip()
        if not value:
            rejection_reasons.append(f"Missing mandatory value: {column}")
            rejection_counts["Missing mandatory value"] += 1
    #validate member id as an integer
    member_id_text = (row.get("member_id") or "").strip()
    if  member_id_text:
        try:
            int(member_id_text)
        except ValueError:
            rejection_reasons.append(f"Invalid member_id: must be an integer {member_id_text}")
    #validate correct format of service date
    service_date_text = (row.get("service_date") or "").strip()
    if service_date_text:
        try:
            parsed_service_date = datetime.strptime(service_date_text, "%Y-%m-%d")
            formatted_service_date = parsed_service_date.strftime("%Y-%m-%d")
            if formatted_service_date != service_date_text:
                rejection_reasons.append("Invalid service_date: must be a real date in YYYY-MM-DD format")
                rejection_counts["Invalid service date"] += 1
        except ValueError:
            rejection_reasons.append("Invalid service_date: must be a real date in YYYY-MM-DD format")
            rejection_counts["Invalid service date"] += 1
    #Validation of positive amount claim
    claim_amt_text = (row.get("claim_amount") or "").strip()
    if claim_amt_text:
        try:
            claim_amt_decimal = Decimal(claim_amt_text)
            if claim_amt_decimal.is_finite():
                if claim_amt_decimal <= 0:
                    rejection_reasons.append("Invalid claim_amount: must be greater than zero")
                    rejection_counts["Non-positive amount"] += 1
            else:
                rejection_reasons.append("Invalid claim_amount: must be numeric")
        except InvalidOperation:
            rejection_reasons.append("Invalid claim_amount: must be numeric")
    #status validation
    claim_status_text = (row.get("claim_status") or "").strip()
    if claim_status_text:
        if claim_status_text not in allowed_statuses:
            rejection_reasons.append("Invalid claim_status: must be APPROVED, DENIED, or PENDING")
            rejection_counts["Invalid status"] += 1
    #duplicate claim id
    claim_id_text = (row.get("claim_id") or "").strip()
    if claim_id_text:
        if claim_id_text in seen_claim_ids:
            rejection_reasons.append("Duplicate claim_id: later occurrence")
            rejection_counts["Duplicate claim_id"] += 1
        else:
            seen_claim_ids.add(claim_id_text)
    return rejection_reasons

def write_csv(output_path, fieldnames, rows):
    with output_path.open(
        mode="w",
        newline="",
        encoding="utf-8"
    ) as output_file:
        writer = csv.DictWriter(output_file, fieldnames=fieldnames, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)

def main():
    script_path = Path(__file__).resolve()
    project_root = script_path.parent.parent.parent
    input_path = project_root/"data"/"input"/"claims_20260803.csv"
    output_dir = project_root/"data"/"output"
    valid_output_path = output_dir/"valid_claims.csv"
    rejected_output_path = output_dir/"rejected_claims.csv"
    log_dir = project_root/"logs"
    log_path = log_dir/"validation.log"
    output_dir.mkdir(parents=True, exist_ok=True)
    log_dir.mkdir(parents=True, exist_ok=True)
    expected_columns = ["claim_id", "member_id", "provider_id", "diagnosis_code", "service_date", "claim_amount", "claim_status"]
    mandatory_columns = ["claim_id", "member_id", "provider_id", "service_date", "claim_amount", "claim_status"]
    allowed_statuses = {"APPROVED", "DENIED", "PENDING"}
    #configuring the logging file
    logging.basicConfig(filename=log_path, level= logging.INFO, format = "%(asctime)s | %(levelname)s | %(message)s", filemode= "w")
    logging.info("Validation Started")
    #opening the CSV file
    #comparing existing columns and actual columns
    with input_path.open(
        mode= "r",
        newline="",
        encoding= "utf-8"
    ) as input_file :
        reader = csv.DictReader(input_file)
        validate_headers(reader.fieldnames, expected_columns)
        valid_rows = []
        rejected_rows = []
        seen_claim_ids = set()
        total_rows = 0
        rejection_counts = Counter()
        for row in reader:
            total_rows += 1
            rejection_reasons = validate_row(row, mandatory_columns, allowed_statuses, seen_claim_ids, rejection_counts)
            #classify the row
            if not rejection_reasons:
                valid_rows.append(row)
            else:
                rejected_row_cpy = row.copy()
                rejected_row_cpy["rejection_reason"] = "; ".join(rejection_reasons)
                rejected_rows.append(rejected_row_cpy)

    #Write valid_claims.csv
    write_csv(valid_output_path, expected_columns, valid_rows)
    print(f"Total_rows: {total_rows}")
    print(f"Valid rows: {len(valid_rows)}")
    print(f"rejected_rows: {len(rejected_rows)}")
    print(f"Input file: {input_path.name}")
    print(f"Missing mandatory value: {rejection_counts['Missing mandatory value']}")
    print(f"Non-positive amount: {rejection_counts['Non-positive amount']}")
    print(f"Invalid status: {rejection_counts['Invalid status']}")
    print(f"Duplicate claim_id: {rejection_counts['Duplicate claim_id']}")
    print(f"Invalid service date: {rejection_counts['Invalid service date']}")
    #write rejected_claim.csv
    extra_column = ["rejection_reason"]
    rejected_headers = expected_columns + extra_column
    write_csv(rejected_output_path, rejected_headers, rejected_rows)
    #logging summary
    logging.info("Total rows processed: %d", total_rows)
    logging.info("Valid rows: %d", len(valid_rows))
    logging.info("Rejected rows: %d", len(rejected_rows))
    logging.info("Input file: %s", input_path.name)
    logging.info("Missing mandatory value: %d", rejection_counts['Missing mandatory value'])
    logging.info("Non-positive amount: %d", rejection_counts['Non-positive amount'])
    logging.info("Invalid status: %d", rejection_counts['Invalid status'])
    logging.info("Duplicate claim_id: %d", rejection_counts['Duplicate claim_id'])
    logging.info("Invalid service date: %d", rejection_counts['Invalid service date'])
    logging.info("Validation completed")
if __name__ == "__main__":
    main()