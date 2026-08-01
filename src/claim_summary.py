claim_amounts = [1200,800,1500,500]
no_of_claims = len(claim_amounts)
total_claim_amounts = sum(claim_amounts)
#avg = sum(claim_amounts)/len(claim_amounts)
avg = (total_claim_amounts/no_of_claims if no_of_claims > 0 else 0 )
print(f"Number of claims = {no_of_claims}")
print(f"Total claim amount = {total_claim_amounts}")
print(f"Average claim amount = {avg}")
