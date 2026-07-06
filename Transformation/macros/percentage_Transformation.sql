{% macro percentage_transformation(column_name) %}
    case
        when {{ column_name }} is null then 0.00
        when contains({{ column_name }}, '%')
            then cast((cast(regexp_replace({{ column_name }}, '%', '', 'g') as float) / 100) as decimal(10,2))
        else cast({{ column_name }} as decimal(10,2))
    end
{% endmacro %}