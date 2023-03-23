CREATE OR REPLACE FUNCTION JSON_to_SQL_query(json_query_string in OUT VARCHAR2) 
                                            RETURN VARCHAR2 
IS
sql_query VARCHAR2(32000);
token VARCHAR2(1000);
str_index NUMBER;
BEGIN
    json_query_string := REGEXP_REPLACE(json_query_string, '  |' || CHR(10) || '|' || CHR(13), '');
    token := REGEXP_SUBSTR(json_query_string, '(\S*)":');
    json_query_string := REGEXP_REPLACE(json_query_string, token, '', 1, 1, 'i');
    
    --geting tables section
    str_index := REGEXP_INSTR(json_query_string, '],', 1, 1, 0, '');
    token := SUBSTR(json_query_string, 1, str_index+1);
    --
    --DBMS_OUTPUT.PUT_LINE(token);
    json_query_string := TRIM(' ' FROM json_query_string);
    json_query_string := REGEXP_REPLACE(json_query_string, token, '', 1, 1, 'ix');
    --token := REGEXP_SUBSTR(json_query_param, '.*(],)', 1, 1, 'ix');
    --DBMS_OUTPUT.PUT_LINE(json_query_string);
    sql_query := parse_table_section(token);
    RETURN sql_query;
END JSON_to_SQL_query;

CREATE OR REPLACE FUNCTION parse_table_section(table_section_string IN OUT VARCHAR2)
                                                RETURN VARCHAR2
IS
res_str VARCHAR2(300);
buffer_str VARCHAR2(500);
name_str VARCHAR2(100);
tabale_name VARCHAR2(50);
left_str_index NUMBER := 1;
right_str_index NUMBER := 0;
name_str_index NUMBER := 1;
reg_exp VARCHAR2(50);
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
        tabale_name := REGEXP_SUBSTR(name_str, '[^"]+', 1, 3, 'ix');
        buffer_str := REGEXP_REPLACE(buffer_str, name_str, '');
        buffer_str := SUBSTR(buffer_str, INSTR(buffer_str, '['));
        name_str_index := 1;
        WHILE name_str_index < (LENGTH(buffer_str) - 3)
        LOOP
            reg_exp := '("col_name":)(\s*)"(\S*)",';
            --name_str := REGEXP_SUBSTR(buffer_str, reg_exp, name_str_index, 1, 'ix');
            name_str_index := REGEXP_INSTR(buffer_str, reg_exp, name_str_index, 1, 0, 'ix');
            res_str := res_str || tabale_name || '.' 
                        || REGEXP_SUBSTR(buffer_str, '[^"]+', name_str_index, 3, 'ix');

            reg_exp := '("alias":)(\s*)((null)|("(\S*)"))}';
            name_str := REGEXP_SUBSTR(buffer_str, reg_exp, name_str_index, 1, 'ix');
            DBMS_OUTPUT.PUT_LINE(name_str);
            --if ALIAS is NULL regexp below can't find substr, that's why this case is handled
            name_str_index := REGEXP_INSTR(buffer_str, reg_exp, name_str_index, 1, 1, 'ix');
            res_str := res_str || ' ' 
                        || REGEXP_SUBSTR(name_str, '[^"]+', 1, 3, 'ix') || ', ';
        END LOOP;
    END LOOP;
    RETURN RTRIM(res_str, ' ,');
END parse_table_section;

CREATE OR REPLACE FUNCTION get_name_item(string_param VARCHAR2,
                                        table_name VARCHAR2,
                                        reg_exp VARCHAR2) RETURN VARCHAR2
IS
BEGIN
    null;
END get_name_item;


BEGIN
    DBMS_OUTPUT.PUT_LINE(LTRIM('[{QWE', '['));
END;


DECLARE
    json_query_param VARCHAR2(300) := '{"select": {"tables": [{"name": "tab_name","columns": [{"name": "col_name", "alias": "alias"}]'; 
    token VARCHAR2(100);
BEGIN
    json_query_param := REGEXP_REPLACE(json_query_param, '  |' || CHR(10) || '|' || CHR(13), '');
    token := REGEXP_SUBSTR(json_query_param, '(\S*)":');
    DBMS_OUTPUT.PUT_LINE(token);
    json_query_param := REGEXP_REPLACE(json_query_param, token, '', 1, 1, 'i');
    --DBMS_OUTPUT.PUT_LINE(REGEXP_REPLACE(token, REGEXP_SUBSTR(token, '(\S*)'), ''));
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
        "from": [{"tab_name": "tab1", "alias": "alias"}, {"tab_name": "tab2", "alias": "alias"}],
        "where": {
            "comment": "/*if where clause consisits from one statement, then no OR|AND bloñk is needed. and|or blocks can be nested*/",
            "and|or": [
                {"comment" : "/*comparators: =, <, >, !=, IN, NOT IN, EXISTS, NOT EXISTS*/"},
                {"comment" : "/*values: simple data type, array: (val1, val2, val3), select block(example below)*/"},
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
BEGIN
    DBMS_OUTPUT.PUT_LINE(JSON_to_SQL_query(json_query_param));
END;
