{% macro map_segment(column_name) %}
    case {{column_name}}
        when 'corp' then 'corporate'
        when 'homeoffice' then 'home office'
        Else {{column_name}}
    end
{% endmacro %}
