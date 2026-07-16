select distinct customer_id ,customer_name ,order_date, First_Value(order_date) over(partition by customer_id , customer_name order by order_date) as valid_From ,
 coalesce((select order_date  from {{ref('stg_sales')}} ss2 where ss2.customer_id = ss.customer_id and ss2.customer_name != ss.customer_name and ss2.order_date > ss.order_date order by order_date limit 1),'9999-12-31') as valid_to
from {{ref('stg_sales')}} ss 
--where customer_id= 1001
--  is_quarantined = false
order by customer_id
-- coalesce((last_value(order_date) over (partition by customer_id , customer_name order by order_date rows between 1 following and unbounded following)),'9999-12-31')