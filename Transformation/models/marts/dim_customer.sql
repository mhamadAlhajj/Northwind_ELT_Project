with lag_table as (
    select 
        customer_id,
        customer_name,
        country,
        segment,
        order_date,
        LAG(customer_name) over (partition by customer_id order by order_date) as previous_Name,
        LAG(country) over (partition by customer_id order by order_date) as previous_country,
        LAG(segment) over (partition by customer_id order by order_date) as previous_segment
    from {{ref('stg_sales')}}
),
check_Change as (
    select 
        customer_id,
        customer_name,
        country,
        segment,
        order_date as valid_from
    from lag_table 
    where 
        previous_Name is null 
        or customer_name is distinct from previous_Name
        or country is distinct from previous_country
        or segment is distinct from previous_segment
),
add_valid_To as (
    select * , 
        lead(valid_from) over (partition by customer_id order by valid_from) as valid_to,
    from check_Change
)
select * ,
    concat(customer_id, '-', valid_from) as Customer_surrogate_id,
    case 
        when valid_to is null then 'yes'
        else 'no'
    End as is_current
from add_valid_To
