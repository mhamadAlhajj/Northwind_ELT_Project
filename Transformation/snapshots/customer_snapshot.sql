{% snapshot customer_snapshot %}
{{
    config(
            target_schema = 'snapshots',
            unique_key='customer_id',
            strategy='check',
            check_cols=['customer_name','segment','country']
)
}}
with ranked as (
select customer_id,customer_name,segment,country , (row_number() over (partition by customer_id order by order_date desc)) as rn
from {{ref('stg_sales')}}
where is_quarantined = false
)
select customer_id,customer_name,segment,country 
from ranked
where rn=1
{% endsnapshot %}
