

def summarize_approved_claims(claims) :
    claim_count = 0
    total_apprvd_amt = 0
    highest_approved_amt = 0
    avg_apprvd_amt = 0
    highest_apprvd_id = None
    for claim in claims :
        if claim["claim_status"] == "APPROVED" :
            claim_count += 1
            total_apprvd_amt += claim["claim_amount"]
            if claim["claim_amount"] > highest_approved_amt :
                highest_apprvd_id = claim["claim_id"]
                highest_approved_amt = claim["claim_amount"]
    avg_apprvd_amt = round(total_apprvd_amt/claim_count if claim_count > 0 else 0,2)
    return {"Approved_claim_count": claim_count,
        "Total_approved_amount": total_apprvd_amt,
        "Average_approved_amount": avg_apprvd_amt,
        "Highest_approved_claim_id" : highest_apprvd_id,
        "Highest_approved_claim_amount" : highest_approved_amt
     }

claims = [
    {"claim_id": "C101", "claim_amount": 1200, "claim_status": "APPROVED"},
    {"claim_id": "C102", "claim_amount": 800, "claim_status": "DENIED"},
    {"claim_id": "C103", "claim_amount": 1500, "claim_status": "APPROVED"},
    {"claim_id": "C104", "claim_amount": 500, "claim_status": "PENDING"},
    {"claim_id": "C105", "claim_amount": 2000, "claim_status": "APPROVED"},
    {"claim_id": "C106", "claim_amount": 750, "claim_status": "DENIED"}
]

result = summarize_approved_claims(claims)
print(f"Approved_claim_count = {result["Approved_claim_count"]}")
print(f"Total_approved_amount = {result["Total_approved_amount"]}")
print(f"Average approved amount = {result["Average_approved_amount"]}")
print(f"Highest approved claim ID = {result["Highest_approved_claim_id"]}")
print(f"Highest approved amount = {result["Highest_approved_claim_amount"]}")
