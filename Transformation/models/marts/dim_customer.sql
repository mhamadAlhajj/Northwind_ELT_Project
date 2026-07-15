Select distinct customer_id , customer_name 
from {{ref('stg_sales')}} 
where customer_id is not null and customer_name is not null 