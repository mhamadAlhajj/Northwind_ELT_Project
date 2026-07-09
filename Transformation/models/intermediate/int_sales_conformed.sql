select ide.* , sf.rate 
from {{ref('int_sales_deduped')}} ide
left join {{ref('stg_countries')}} sc 
on sc.common_name = ide.country
left join {{ref('stg_fx')}} sf 
on list_contains(sc.currency_codes,sf.currency) 
