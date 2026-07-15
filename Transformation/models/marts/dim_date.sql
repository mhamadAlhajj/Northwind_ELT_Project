with RECURSIVE date_series as (
    select min(order_date) as dt
    from {{ref('int_sales_conformed')}}
    union all
    select dt + INTERVAL '1 day'
    from date_series
    where dt < (select max(order_date) + INTERVAL '5 year' as max_date
    from {{ref('stg_sales')}})
    where order_date is not null
)
select 
    dt as date_key,
    extract(Year from dt) as year,
    extract(quarter from dt) as quarter,
    extract(month from dt) as month,
    extract(day from dt) as day,
    DayName(dt) as day_name,
    extract(DOW from dt) as day_of_week,
    extract(week from dt) as week_of_year
 from date_series