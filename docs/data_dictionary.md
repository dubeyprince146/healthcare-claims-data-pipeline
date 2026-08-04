| Columns | Data type | Required? | Example | Validation rule |
| claim_id | varchar(10) | Y | C101 | This must be a primary key which identifies uniquily |
| member_id | int | Y | 1234 | Required integer; may repeat because a member can have multiple claims.|
| provider_id | varchar(10) | Y | P1021 | Required identifier; may repeat because a provider can process multiple claims.
 |
| diagnosis_code | varchar(20) | N | D1213 | This can be null also |
| service_date | date | Y | 2026-08-15 | Must be a valid calendar date in YYYY-MM-DD format. |
| claim_amount | NUMBER(12,2) | Y | 2000.5 | Claim amount must be greater than zero |
| claim_status | varchar | Y | APPROVED | Allowed statuses : APPROVED, DENIED, PENDING |

Which field or combination uniquely identifies one claim?
-> claim_id
Why did you choose it?
->Becasue each claim has an uqique id and this cant be duplicated.
What exactly makes two rows duplicates?
-> member_id and provider_id should not be unique across claim rows:
A member can have multiple claims.
A provider can process multiple claims.
Only claim_id uniquely identifies one claim.
Which fields are mandatory?
-> All except diagosis_code
What assumptions are you making?
-> Assuming that there should be a member for each claim along with provider and also claim amount should be always positive.