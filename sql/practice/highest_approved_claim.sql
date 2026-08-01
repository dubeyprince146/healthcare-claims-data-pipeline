WITH claims (
    claim_id,
    provider_id,
    claim_amount,
    claim_status
) AS (
    SELECT * FROM VALUES
        ('C101', 'P01', 1200, 'APPROVED'),
        ('C102', 'P01', 1500, 'APPROVED'),
        ('C103', 'P01', 1500, 'APPROVED'),
        ('C104', 'P02',  900, 'DENIED'),
        ('C105', 'P02', 1100, 'APPROVED'),
        ('C106', 'P02',  700, 'APPROVED'),
        ('C107', 'P03', 2000, 'DENIED'),
        ('C108', 'P03', 1750, 'APPROVED')
)
SELECT provider_id,
claim_id,
claim_amount
FROM claims
where claim_status = 'APPROVED'
qualify(rank() over(partition by provider_id order by claim_amount desc)) = 1
order by provider_id,claim_id;