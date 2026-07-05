{% macro normalize_decimal_separator(column_name) %}
    case
        when position(',' in regexp_replace({{ column_name }}, '[^0-9.,]', '', 'g'))
                > position('.' in regexp_replace({{ column_name }}, '[^0-9.,]', '', 'g'))
            and position(',' in regexp_replace({{ column_name }}, '[^0-9.,]', '', 'g')) > 0
            and position('.' in regexp_replace({{ column_name }}, '[^0-9.,]', '', 'g')) > 0
        then replace(replace(replace(regexp_replace({{ column_name }}, '[^0-9.,!]', '', 'g'), ',', '!'), '.', ','), '!', '.')
        when position(',' in regexp_replace({{ column_name }}, '[^0-9.,]', '', 'g')) > 0
            and position('.' in regexp_replace({{ column_name }}, '[^0-9.,]', '', 'g')) = 0
            and length(substring(regexp_replace({{ column_name }}, '[^0-9.,]', '', 'g'), position(',' in regexp_replace({{ column_name }}, '[^0-9.,]', '', 'g')) + 1)) <= 2
        then replace(regexp_replace({{ column_name }}, '[^0-9.,]', '', 'g'), ',', '.')
        when position('.' in regexp_replace({{ column_name }}, '[^0-9.,]', '', 'g')) > 0
            and position(',' in regexp_replace({{ column_name }}, '[^0-9.,]', '', 'g')) = 0
            and length(substring(regexp_replace({{ column_name }}, '[^0-9.,]', '', 'g'), position('.' in regexp_replace({{ column_name }}, '[^0-9.,]', '', 'g')) + 1)) > 2
        then replace(regexp_replace({{ column_name }}, '[^0-9.,]', '', 'g'), '.', ',')
        else regexp_replace({{ column_name }}, '[^0-9.,]', '', 'g')
    end
{% endmacro %}
