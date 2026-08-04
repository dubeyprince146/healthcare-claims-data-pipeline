    WITH claims (
        claim_id,
        provider_id,
        service_date,
        claim_amount,
        claim_status
    ) AS (
        SELECT * FROM VALUES
            ('C201', 'P01', '2026-01-10', 1000, 'APPROVED'),
            ('C202', 'P01', '2026-01-22',  500, 'APPROVED'),
            ('C203', 'P01', '2026-02-05', 2000, 'APPROVED'),
            ('C204', 'P01', '2026-02-12',  300, 'DENIED'),
            ('C205', 'P01', '2026-03-02', 1800, 'APPROVED'),
            ('C206', 'P02', '2026-01-08',  700, 'APPROVED'),
            ('C207', 'P02', '2026-02-14', 1000, 'APPROVED'),
            ('C208', 'P02', '2026-03-18', 1500, 'APPROVED'),
            ('C209', 'P03', '2026-01-09',  900, 'DENIED'),
            ('C210', 'P03', '2026-02-11',  500, 'APPROVED'),
            ('C211', 'P03', '2026-03-21',  900, 'APPROVED')
    ),
    current_total as(
    select
    provider_id,
    date_trunc('MONTH',date(service_date)) as claim_month,
    sum(claim_amount) as current_total
    from claims
    where claim_status = 'APPROVED'
    group by all),

    previous_total as (
    select
    provider_id,
    claim_month,
    current_total,
    lag(current_total) over(partition by provider_id order by claim_month) as previous_total
    from current_total
    )
        select
        provider_id,
        claim_month,
        current_total as current_approved_total,
        previous_total as previous_approved_total,
        (current_total-previous_total) as Increase_amount
    from previous_total
    where (current_total-previous_total)>0
    order by provider_id,claim_month;