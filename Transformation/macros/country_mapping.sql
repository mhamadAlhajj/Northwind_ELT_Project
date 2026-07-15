{% macro map_country_code(column_name) %}
    case upper(trim(replace({{ column_name }}, '.', '')))
        when 'CA' then 'CA'
        when 'CANADA' then 'CA'

        when 'DE' then 'DE'
        when 'DEUTSCHLAND' then 'DE'
        when 'GERMANY' then 'DE'

        when 'ES' then 'ES'
        when 'ESPAÑA' then 'ES'
        when 'SPAIN' then 'ES'

        when 'FR' then 'FR'
        when 'FRANCE' then 'FR'

        when 'GB' then 'GB'
        when 'UK' then 'GB'
        when 'UNITED KINGDOM' then 'GB'

        when 'JP' then 'JP'
        when 'JAPAN' then 'JP'

        when 'US' then 'US'
        when 'USA' then 'US'
        when 'UNITED STATES' then 'US'
        when 'UNITED STATES OF AMERICA' then 'US'
        --because these countries don't have alpha 2 
        when 'Somaliland' then 'Somaliland'
        when 'South Ossetia' then 'South Ossetia'
        when 'Abkhazia' then 'Abkhazia'
        when 'Northern Cyprus' then 'Northern Cyprus'
        else {{column_name}}
    end
{% endmacro %}
