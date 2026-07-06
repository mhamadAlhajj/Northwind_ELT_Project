{% macro date_transformation(column_name) %}
    coalesce(
            try_cast({{column_name}} as date),
            cast(try_strptime({{column_name}}, '%m/%d/%Y') as date),
            cast(try_strptime({{column_name}}, '%d %b %Y') as date),
            date '1899-12-30' + cast({{column_name}} as integer)
        )
{% endmacro %}