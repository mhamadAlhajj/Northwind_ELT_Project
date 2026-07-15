select * from {{ref('stg_sales')}} ide
left join {{ref('stg_countries')}} sc
    on (coalesce(nullif(sc.alpha_2,''), sc.common_name) = ide.country)
where sc.common_name is null and ide.country is not null