{{
    config(
        materialized='incremental',
        unique_key='order_line_id',
        incremental_strategy='delete+insert'
    )
}}

with cte_join as(
 -- The purpose of this join is to convert all amounts to USD. However, if a country has more than one currency, this join may produce duplicate records.
 -- To avoid duplicates, we use `ROW_NUMBER()` to keep only the first row and select the most recent exchange rate available before the order date.
    select order_id,customer_id,customer_name , product_id , product_name , order_date,ship_date ,quantity,unit_price,amount,segment,category,order_channel,country,
        common_name as country_name,discount ,tax ,ide._dlt_id ,ide._dlt_load_id,loaded_date ,rate, (amount / rate) as amount_usd,
        -- same grain as int_sales_deduped's dedup key, so a late correction re-lands on the same key instead of duplicating
        order_id || '-' || product_id || '-' || cast(sign(quantity) as varchar) as order_line_id
    from {{ref('int_sales_deduped')}} ide
    left join {{ref('stg_countries')}} sc
        on (coalesce(nullif(sc.alpha_2,''), sc.common_name) = ide.country)
    left join {{ref('stg_fx')}} sf
        on list_contains(sc.currency_codes, sf.currency)
        and sf.rate_date <= ide.order_date
        and sf.is_quarantined = false
    {% if is_incremental() %}
    where ide.loaded_date >= (select coalesce(max(loaded_date), '1900-01-01'::timestamp) from {{ this }}) - interval '3 days'
    {% endif %}
    qualify row_number() over (
        partition by ide._dlt_id
        order by sf.rate_date desc
    ) = 1
),
cte_quarantine as (
select *  , nullif(
            concat_ws(
                ', ',
                case when country_name is null then 'missing_country_mapping' end,
                case when rate is null then 'missing_rate' end
            ),
            ''
        ) as quarantine_reason
from cte_join
)
select * , quarantine_reason is not null as is_quarantined
from cte_quarantine
