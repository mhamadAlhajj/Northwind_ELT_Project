{% macro clean_text(column_name) %}
    coalesce(lower(trim(regexp_replace({{column_name}}, '[^a-zA-Z ]', '', 'g'))), 'unknown')
{% endmacro %}
