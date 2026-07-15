select * from {{ref('int_sales_conformed')}}
where rate is not null and amount_usd is null