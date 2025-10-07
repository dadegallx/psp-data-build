{% macro indicator_color_to_score(value_expr) %}
  /*
    Convert stoplight color value to numeric score
    value: 1=Red, 2=Yellow, 3=Green
    score: Red=0.0, Yellow=0.5, Green=1.0
  */
  CASE {{ value_expr }}
    WHEN 1 THEN 0.0
    WHEN 2 THEN 0.5
    WHEN 3 THEN 1.0
    ELSE NULL
  END
{% endmacro %}
