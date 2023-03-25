CREATE OR REPLACE FUNCTION parse_name_section(name_section_string VARCHAR2,
                                                search_param VARCHAR2,
                                                table_name VARCHAR2 DEFAULT NULL) RETURN VARCHAR2
IS
name_str_index NUMBER := 1;
alias_str VARCHAR2(100);
res_str VARCHAR2(300);
reg_exp VARCHAR2(50);
res_tab_name VARCHAR2(50) := CASE UPPER(search_param)
                            WHEN 'COL_NAME' THEN table_name || '.'
                            ELSE NULL
                        END;
BEGIN
    WHILE name_str_index < (LENGTH(name_section_string) - 3)
    LOOP
        reg_exp := '("' || search_param || '":)(\s*)"(\S*)",';
        name_str_index := REGEXP_INSTR(name_section_string, reg_exp, name_str_index, 1, 0, 'ix');
        res_str := res_str || res_tab_name
                    || REGEXP_SUBSTR(name_section_string, '[^"]+', name_str_index, 3, 'ix');

        reg_exp := '("alias":)(\s*)((null)|("(\S*)"))}';
        alias_str := REGEXP_SUBSTR(name_section_string, reg_exp, name_str_index, 1, 'ix');
        --if ALIAS is NULL regexp below can't find substr, that's why this case is handled
        name_str_index := REGEXP_INSTR(name_section_string, reg_exp, name_str_index, 1, 1, 'ix');
        res_str := res_str || ' ' 
                    || REGEXP_SUBSTR(alias_str, '[^"]+', 1, 3, 'ix') || ', ';
    END LOOP;
    RETURN RTRIM(res_str, ' ,');
END parse_name_section;

CREATE OR REPLACE FUNCTION parse_table_section(table_section_string IN OUT VARCHAR2)
                                                RETURN VARCHAR2
IS
res_str VARCHAR2(300);
buffer_str VARCHAR2(500);
name_str VARCHAR2(100);
table_name VARCHAR2(50);
left_str_index NUMBER := 1;
right_str_index NUMBER := 0;
BEGIN
    table_section_string := LTRIM(RTRIM(table_section_string, ', '), ' ' || CHR(91) || CHR(8));
    table_section_string := REGEXP_REPLACE(table_section_string, 
                                REGEXP_SUBSTR(table_section_string, '[^:]+:'), '');
    table_section_string := LTRIM(RTRIM(table_section_string, ', '), ' ' || CHR(91) || CHR(8));

    WHILE right_str_index < LENGTH(table_section_string)
    LOOP
        -- '}]}' is devider between tables in this section
        right_str_index := REGEXP_INSTR(table_section_string, '}]}', left_str_index, 1, 1, 'x');
        buffer_str := SUBSTR(table_section_string, left_str_index, right_str_index);
        left_str_index := right_str_index + 1;
        --this step can be skipped because last part of regexp can directly extract name
        name_str := REGEXP_SUBSTR(buffer_str, '("tab_name":)(\s*)"(\S*)",', 1, 1, 'ix');
        --
        table_name := REGEXP_SUBSTR(name_str, '[^"]+', 1, 3, 'ix');
        buffer_str := REGEXP_REPLACE(buffer_str, name_str, '');
        buffer_str := SUBSTR(buffer_str, INSTR(buffer_str, '['));
        res_str := res_str 
                    || parse_name_section(buffer_str, 'col_name', table_name) || ', ';
    END LOOP;
    RETURN RTRIM(res_str, ' ,');
END parse_table_section;

CREATE OR REPLACE FUNCTION parse_where_section(where_section_string VARCHAR2) RETURN VARCHAR2
IS
BEGIN
    RETURN NULL;
END parse_where_section;

CREATE OR REPLACE FUNCTION parse_select_query(json_query_string IN OUT VARCHAR2) 
                                                RETURN VARCHAR2
IS
sql_query VARCHAR2(32000);
token VARCHAR2(1000);
str_index NUMBER;
BEGIN
    --geting tables section
    str_index := REGEXP_INSTR(json_query_string, '}],', 1, 1, 1, 'i');
    token := SUBSTR(json_query_string, 1, str_index-1);
    --DBMS_OUTPUT.PUT_LINE('TOKEN1: ' || token);
    json_query_string := REPLACE(json_query_string, token, '');
    sql_query := parse_table_section(token);
    --
    --USE str_index INSTEAD OF 1 WHEN WHERE IS NO REPLACE()
    token := TRIM('"' FROM REGEXP_SUBSTR(json_query_string, '("(\S*)")', 1));
    IF UPPER(token) != 'FROM' THEN
        RAISE_APPLICATION_ERROR(-20001, 'WRONG PARSE INPUT EXPECTED(FROM) GOT (' || token || ')');
    END IF ;
    sql_query := sql_query || ' FROM';
    str_index := INSTR(json_query_string, ']') + 1;
    token := SUBSTR(json_query_string, INSTR(json_query_string, '['), str_index - INSTR(json_query_string, '['));
    sql_query := sql_query || ' ' || parse_name_section(token, 'tab_name');
    token := TRIM('"' FROM REGEXP_SUBSTR(json_query_string, '("(\S*)")', str_index));
    IF UPPER(token) = 'WHERE' THEN
        sql_query := sql_query || ' ' || parse_where_section(token);
    END IF;
    DBMS_OUTPUT.PUT_LINE('TOKEN1: ' || token);
    RETURN sql_query;
END parse_select_query;

CREATE OR REPLACE FUNCTION JSON_to_SQL_query(json_query_string in OUT VARCHAR2) 
                                            RETURN VARCHAR2 
IS
sql_query VARCHAR2(32000);
token VARCHAR2(1000);
--str_index NUMBER;
BEGIN
    json_query_string := REGEXP_REPLACE(json_query_string, '  |' || CHR(10) || '|' || CHR(13), '');
    token := REGEXP_SUBSTR(json_query_string, '(\S*)":');
    token := LTRIM(RTRIM(token, '":'), '"{');
    --DBMS_OUTPUT.PUT_LINE(token);
    json_query_string := REGEXP_REPLACE(json_query_string, token, '', 1, 1, 'i');
    DBMS_OUTPUT.PUT_LINE(json_query_string);
    sql_query := CASE UPPER(token)
                    WHEN 'SELECT' THEN sql_query 
                        || 'SELECT ' || parse_select_query(json_query_string)
                    ELSE NULL
                END;
    --json_query_string := TRIM(' ' FROM json_query_string);
    RETURN sql_query;
END JSON_to_SQL_query;




DECLARE
    json_query_param VARCHAR2(300) := '[{"columns": [{"col_name": "col11_name", "alias": null},{"col_name": "col12_name", "alias": "al12"}]},'; 
    token VARCHAR2(100);
BEGIN
    DBMS_OUTPUT.PUT_LINE(parse_name_section(json_query_param, 'col_name', 'tab1'));
END;


DECLARE
    json_query_param VARCHAR2(32000) :=  '{
    "select": {
        "tables": [
            {"tab_name": "tab1",
            "columns": [
                {"col_name": "col11_name", "alias": null          },
                {"col_name": "col12_name", "alias": "al12"}
            ]}                        ,
            {"tab_name": "tab2"      ,
            "columns": [
                {"col_name": "col21_name", "alias": "al21"},
                {"col_name": "col22_name", "alias": "al22"}
            ]}
        ],
        "from": [{"tab_name": "tab1", "alias": null}, {"tab_name": "tab2", "alias": "alias"}],
        "where": {
            "and|or": [
                {"col_name": {
                    "comparator": "value"
                    }
                },
                { "and|or": []},
                {"salary": {
                        "in": {
                            "select": {
                                "tables": [
                                    {"tab_name": "tab3",
                                    "columns": [
                                        {"col_name": "col1_name", "alias": "alias"},
                                        {"col_name": "col2_name", "alias": "alias"}
                                    ]}
                                ]
                            }
                        }
                    }
                }
            ]
        },
        "(INNER|LEFT|RIGHT|FULL) JOIN": {
            "select|tables blok": {},
            "on": {
                "comment": "/*The same nesting rules as in and|or block*/",
                "col_name|alias": {
                    "=": "other_col_name|alias"
                }
            }
        }
    }
}';
  je JSON_ELEMENT_T;
  jo JSON_OBJECT_T;
BEGIN
    --DBMS_OUTPUT.PUT_LINE(JSON_to_SQL_query(json_query_param));
    je := JSON_ELEMENT_T.parse(json_query_param);
    DBMS_OUTPUT.put_line(je.to_string);
END;

DECLARE
  je JSON_ELEMENT_T;
  jo JSON_OBJECT_T;
BEGIN
  je := JSON_ELEMENT_T.parse('{"tab_name": "tab1",
            "columns": [
                {"col_name": "col1_name", "alias": "alias"},
                {"col_name": "col1_name", "alias": "alias"}
            ]}');
  IF (je.is_Object) THEN
    jo := treat(je AS JSON_OBJECT_T);
    jo.put('price', 149.99);
  END IF;
  DBMS_OUTPUT.put_line(je.to_string);
END;
