with cte_join as(
    select order_id,customer_id,customer_name , product_id , product_name , order_date,ship_date ,quantity,unit_price,amount,segment,category,order_channel,country,
        discount ,tax ,ide._dlt_id ,ide._dlt_load_id,loaded_date ,rate, (amount / rate) as amount_usd
    from {{ref('int_sales_deduped')}} ide
    left join {{ref('stg_countries')}} sc 
        on sc.common_name = ide.country
    left join {{ref('stg_fx')}} sf 
        on list_contains(sc.currency_codes, sf.currency)
        and sf.rate_date <= ide.order_date
        and sf.is_quarantined = false
    qualify row_number() over (
        partition by ide._dlt_id 
        order by sf.rate_date desc
    ) = 1
),
cte_quarantine as (
select *  , nullif((
                case when rate is null then 'missing_rate' end
            ),
            ''
        ) as quarantine_reason
from cte_join
)
select * , quarantine_reason is not null as is_quarantined
from cte_quarantine