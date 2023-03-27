CREATE OR REPLACE PACKAGE json_parser AS
    ----------
    ---SELECT section
    FUNCTION parse_name_section(json_query_string JSON_ARRAY_T, search_name VARCHAR2,
                                table_name VARCHAR2 DEFAULT NULL)
                                RETURN VARCHAR2;
    FUNCTION parse_table_section(json_query_string JSON_ARRAY_T) RETURN VARCHAR2;
    FUNCTION parse_scalar_array(json_query_string JSON_ARRAY_T) RETURN VARCHAR2;
    FUNCTION parse_select(json_query_string JSON_OBJECT_T) RETURN VARCHAR2;
    FUNCTION condition_checker(json_query_string JSON_OBJECT_T, 
                                is_in_join_segment BOOLEAN DEFAULT FALSE) 
                                RETURN VARCHAR2;
    FUNCTION parse_where_section(json_query_string JSON_OBJECT_T) RETURN VARCHAR2;
    FUNCTION parse_compound_conditions(json_query_string JSON_ARRAY_T,
                                        join_condition VARCHAR2,
                                        is_in_join_segment BOOLEAN DEFAULT FALSE)
                                        RETURN VARCHAR2;
    FUNCTION parse_join_section(json_query_string JSON_ARRAY_T) RETURN VARCHAR2;
--------------------------
--DML section
     FUNCTION parse_values_as_array(json_columns JSON_ARRAY_T, 
                                    json_values JSON_ARRAY_T,
                                    new_val_type NUMBER) RETURN VARCHAR2;
    FUNCTION parse_values_as_select(json_columns JSON_ARRAY_T, 
                                    json_values JSON_OBJECT_T,
                                    new_val_type NUMBER) RETURN VARCHAR2;
    FUNCTION parse_new_values_section(json_columns JSON_ARRAY_T, 
                                    json_values JSON_ELEMENT_T,
                                    new_val_type NUMBER) RETURN VARCHAR2;
    FUNCTION parse_dml_section(json_query_string JSON_OBJECT_T) RETURN VARCHAR2;
    FUNCTION parse_JSON_to_SQL(json_query_string JSON_OBJECT_T) RETURN VARCHAR2;
END json_parser;


CREATE OR REPLACE PACKAGE BODY json_parser AS
-----------------------
--SELECT section
    FUNCTION parse_name_section(json_query_string JSON_ARRAY_T, search_name VARCHAR2,
                                table_name VARCHAR2 DEFAULT NULL)
                                RETURN VARCHAR2
    IS
        buff_json_object JSON_OBJECT_T;
        res_tab_name VARCHAR2(51) := NULL;
        res_str VARCHAR2(300);
    BEGIN
        IF table_name IS NOT NULL THEN
            res_tab_name := table_name || '.';
        END IF;
        FOR i IN 0..json_query_string.get_size - 1
        LOOP
            buff_json_object := TREAT(json_query_string.get(i) AS JSON_OBJECT_T);
            res_str := res_str || ' ' || res_tab_name 
                    || buff_json_object.get_String(search_name) || ' '
                    || buff_json_object.get_String('alias') || ',';
                    
        END LOOP;
        RETURN RTRIM(res_str, ',');
    END parse_name_section;
    
    
    FUNCTION parse_table_section(json_query_string JSON_ARRAY_T)
                                                    RETURN VARCHAR2
    IS
        res_str VARCHAR2(2000);
        table_name VARCHAR2(50);
        buff_json_object JSON_OBJECT_T;
        json_names JSON_ARRAY_T;
    BEGIN
        FOR i in  0..json_query_string.get_size - 1
        LOOP
            --IF NOT (json_query_string.has('tab_name') 
            --        AND json_query_string.has('columns')) THEN
            --    RAISE_APPLICATION_ERROR(-20001, 'There is no smth in "tables" section');
            --END IF;
            buff_json_object := TREAT(json_query_string.get(i) AS JSON_OBJECT_T);
            table_name := buff_json_object.get_String('tab_name');
            res_str := res_str 
                    || parse_name_section(TREAT(buff_json_object.get('columns') AS JSON_ARRAY_T), 
                                            'col_name', table_name)
                    || ',';
    
        END LOOP;
        RETURN RTRIM(res_str, ',');
    END parse_table_section;
    
    
    FUNCTION parse_scalar_array(json_query_string JSON_ARRAY_T) RETURN VARCHAR2
    IS
        res_str VARCHAR2(300) := '(';
        buff_json_element JSON_ELEMENT_T;
    BEGIN
        FOR i IN 0..json_query_string.get_size - 1
        LOOP
            buff_json_element := json_query_string.get(i);
            IF NOT buff_json_element.is_scalar THEN
                RAISE_APPLICATION_ERROR(-20005, 'Not scalar element was found in supposed scalar array');
            END IF;
            res_str := res_str || buff_json_element.to_string || ', '; 
        END LOOP;
        
        RETURN REGEXP_REPLACE(RTRIM(res_str, ', ') || ')', '"', '' || CHR(39));
    END parse_scalar_array;
    
    
    FUNCTION parse_simple_condition(json_query_string JSON_OBJECT_T,
                                    is_in_join_segment BOOLEAN DEFAULT FALSE)
                                                        RETURN VARCHAR2
    IS
        res_str VARCHAR2(300);
        buff_json_element JSON_ELEMENT_T;
        buff_json_object JSON_OBJECT_T;
        res_tab_name VARCHAR2(51);
    BEGIN
        IF json_query_string.has('tab_name') THEN
            res_tab_name := json_query_string.get_string('tab_name') || '.';
        END IF;
    
        res_str := res_tab_name || json_query_string.get_string('col_name') || ' ';
                    
        IF is_in_join_segment AND json_query_string.get_string('comparator') != '=' THEN
            RAISE_APPLICATION_ERROR(-20009, 'Unexpected value (' 
                || json_query_string.get_string('comparator') || ') expected (=) in "join section"');
        END IF;
        
        res_str := res_str || UPPER(json_query_string.get_string('comparator'));
        buff_json_element := json_query_string.get('value'); 
        
        IF is_in_join_segment THEN
            buff_json_object := TREAT(buff_json_element AS JSON_OBJECT_T);
            res_str := res_str || res_tab_name || buff_json_object.get_string('col_name');
        ELSIF buff_json_element.is_scalar THEN
            res_str := res_str || ' ' || buff_json_element.to_string;
        ELSIF buff_json_element.is_array THEN
            res_str := res_str || ' ' || parse_scalar_array(TREAT(buff_json_element AS JSON_ARRAY_T));
        ELSE
            buff_json_object := TREAT(buff_json_element AS JSON_OBJECT_T);
        
            IF NOT buff_json_object.has('select') THEN
                RAISE_APPLICATION_ERROR(-20006, 'Not supported value in comparison');
            END IF;
            
            res_str := res_str || ' (' || parse_select(buff_json_object.get_object('select')) || ')';
        END IF;
        RETURN REPLACE(res_str, '"', '' || CHR(39));
    END parse_simple_condition;
    
    
    FUNCTION parse_compound_conditions(json_query_string JSON_ARRAY_T,
                                        join_condition VARCHAR2,
                                        is_in_join_segment BOOLEAN DEFAULT FALSE)
                                        RETURN VARCHAR2
    IS
        buff_json_object JSON_OBJECT_T;
        res_str VARCHAR2(1000) := '(';
    BEGIN
        FOR i IN 0..json_query_string.get_size - 1
        LOOP
            buff_json_object := TREAT(json_query_string.get(i) AS JSON_OBJECT_T);
            res_str := res_str || condition_checker(buff_json_object, is_in_join_segment) 
                                || ' ' || join_condition || ' ';
        END LOOP;
        RETURN RTRIM(res_str, join_condition || ' ') || ')';
    END parse_compound_conditions;
    
    
    FUNCTION condition_checker(json_query_string JSON_OBJECT_T, 
                                is_in_join_segment BOOLEAN DEFAULT FALSE) 
                                RETURN VARCHAR2
    IS
    BEGIN
        IF json_query_string.has('or') THEN
            RETURN parse_compound_conditions(json_query_string.get_array('or'), 'OR', is_in_join_segment);
        ELSIF json_query_string.has('and') THEN
            RETURN parse_compound_conditions(json_query_string.get_array('and'), 'AND', is_in_join_segment);
        ELSIF json_query_string.has('comparison') THEN
            RETURN parse_simple_condition(json_query_string.get_object('comparison'), is_in_join_segment);
        ELSE
            RAISE_APPLICATION_ERROR(-20004, 'There is no "comparison" in "where" section');
        END IF;   
    END condition_checker;
    
    FUNCTION parse_where_section(json_query_string JSON_OBJECT_T) RETURN VARCHAR2
    IS
    BEGIN
        RETURN condition_checker(json_query_string);
    END parse_where_section;
    
    
    FUNCTION parse_join_section(json_query_string JSON_ARRAY_T) RETURN VARCHAR2
    IS
        buff_json_object JSON_OBJECT_T;
        jo JSON_OBJECT_T;
        res_str VARCHAR2(2000);
    BEGIN
        FOR i IN 0..json_query_string.get_size - 1
        LOOP
            buff_json_object := TREAT(json_query_string.get(i) AS JSON_OBJECT_T);
            res_str := res_str || ' '
                    || UPPER(buff_json_object.get_string('join_type')) || ' JOIN ';
            IF buff_json_object.has('select') THEN
                continue;
                res_str := res_str || '(' || parse_select(buff_json_object) || ')';
            ELSIF buff_json_object.has('table') THEN
                jo := buff_json_object.get_object('table');
                res_str := res_str || jo.get_string('tab_name') || ' ' || jo.get_string('alias');
            ELSE
                RAISE_APPLICATION_ERROR(-20008, 'There is no necessary join parameter in "join" section');
            END IF;
            res_str := res_str || ' ON ' 
                        || condition_checker(buff_json_object.get_object('on'), TRUE);
        END LOOP;
        RETURN res_str;
    END parse_join_section;
    
    
    FUNCTION parse_group_by_section(json_query_string JSON_ARRAY_T) RETURN VARCHAR2
    IS
    BEGIN
        RETURN NULL;
    END parse_group_by_section;
    
    
    FUNCTION parse_select(json_query_string JSON_OBJECT_T) RETURN VARCHAR2
    IS
        res_str VARCHAR2(32000) := 'SELECT';
    BEGIN
        IF NOT json_query_string.has('tables') THEN
            RAISE_APPLICATION_ERROR(-20002, 'There is now "tables" section');
        END IF;
        res_str := res_str || 
            parse_table_section(json_query_string.get_array('tables'));
        IF NOT json_query_string.has('from') THEN
            RAISE_APPLICATION_ERROR(-20003, 'There is now "from" section');
        END IF;
        res_str := res_str || ' FROM' 
                || parse_name_section(json_query_string.get_array('from'), 'tab_name');
        IF json_query_string.has('where') THEN
            res_str := res_str || ' WHERE ' 
                || parse_where_section(json_query_string.get_object('where'));
        END IF;
        IF json_query_string.has('join') THEN
            res_str := res_str
                || parse_join_section(json_query_string.get_array('join'));
        END IF;
        IF json_query_string.has('group by') THEN
            res_str := res_str
                || parse_group_by_section(json_query_string.get_array('group by'));
        END IF;
        RETURN res_str;
    END parse_select;
--------------------------
--DML section
    -- 0 == INSERT; 1 == UPDATE
    FUNCTION parse_values_as_array(json_columns JSON_ARRAY_T, 
                                    json_values JSON_ARRAY_T,
                                    new_val_type NUMBER) RETURN VARCHAR2
    IS
        res_str VARCHAR2(300);
    BEGIN
        IF json_columns.get_size != json_values.get_size THEN
            RAISE_APPLICATION_ERROR(-20011, 'Mismatched values in "DML": columns(' 
                || json_columns.get_size || '), values(' || json_values.get_size || ')');
        END IF;
        IF new_val_type = 0 THEN
            RETURN parse_scalar_array(json_columns) || CHR(10) 
                    || 'VALUES' || CHR(10) || parse_scalar_array(json_values);
        ELSE
            FOR i IN 0..json_columns.get_size - 1
            LOOP
                res_str := res_str || json_columns.get_string(i) 
                        || ' = ' || json_values.get_string(i) || CHR(10);
            END LOOP;
        END IF;
        RETURN res_str;
    END parse_values_as_array;

    -- 0 == INSERT; 1 == UPDATE
    FUNCTION parse_values_as_select(json_columns JSON_ARRAY_T, 
                                    json_values JSON_OBJECT_T,
                                    new_val_type NUMBER) RETURN VARCHAR2
    IS
    BEGIN
        IF NOT json_values.has('select') THEN
            RAISE_APPLICATION_ERROR(-20012, 'Mismatched value in "DML": 
                                            ("select") not found)');
        END IF;
        IF new_val_type = 0 THEN
            RETURN parse_scalar_array(json_columns) 
                    || CHR(10) || '(' || parse_select(json_values) || ')';
        ELSE
            IF json_columns.get_size != 1 THEN
                RAISE_APPLICATION_ERROR(-20014, 'Mismatched value in "update": 
                                                MUST be one column for "select"');
            END IF;
            RETURN json_columns.get_string(0) || ' = ' || '(' || parse_select(json_values) || ')';
        END IF;
    END parse_values_as_select;
    
    -- 0 == INSERT; 1 == UPDATE
    FUNCTION parse_new_values_section(json_columns JSON_ARRAY_T, 
                                    json_values JSON_ELEMENT_T,
                                    new_val_type NUMBER) RETURN VARCHAR2
    IS
    BEGIN
        IF json_values.is_array THEN
            RETURN parse_values_as_array(json_columns, TREAT(json_values AS JSON_ARRAY_T), new_val_type);
        ELSIF json_values.is_object THEN
            RETURN parse_values_as_select(json_columns, TREAT(json_values AS JSON_OBJECT_T), new_val_type);
        ELSE
            RAISE_APPLICATION_ERROR(-20013, 'Wrong value type for "values" in "insert"');
        END IF;
    END parse_new_values_section;


    FUNCTION parse_dml_section(json_query_string JSON_OBJECT_T) RETURN VARCHAR2
    IS
        dml_type VARCHAR2(6);
        res_str VARCHAR2(10000);
    BEGIN

        IF NOT json_query_string.has('tab_name') THEN
            RAISE_APPLICATION_ERROR(-20010, 'There is no necessary "tab_name" parameter in DML');
        END IF;
        dml_type := json_query_string.get_string('type');
        res_str := CASE UPPER(dml_type)
                        WHEN 'INSERT' THEN
                            'INSERT INTO ' || json_query_string.get_string('tab_name') 
                            || parse_new_values_section(json_query_string.get_array('columns'), 
                                                        json_query_string.get('values'), 0)
                        WHEN 'UPDATE' THEN
                            'UPDATE ' || json_query_string.get_string('tab_name') 
                            || parse_new_values_section(json_query_string.get_array('columns'), 
                                                        json_query_string.get('values'), 1)
                        WHEN 'DELETE' THEN 
                            'DELETE FROM ' || json_query_string.get_string('tab_name')
                        ELSE NULL
                    END;
        IF res_str IS NULL THEN
            RAISE_APPLICATION_ERROR(-20010, 'There is no necessary "type" parameter in DML');
        END IF;
        IF json_query_string.has('where') THEN
            res_str := res_str || parse_where_section(json_query_string.get_object('where'));
        END IF;
        RETURN res_str;
    END parse_dml_section; 
---------------------
--DDL
    FUNCTION get_full_cons_name(short_cons_name VARCHAR2) RETURN VARCHAR2
    IS
    BEGIN
        RETURN CASE UPPER(short_cons_name)
                    WHEN 'P' THEN 'PRIMARY KEY'
                    WHEN 'U' THEN 'UNIQUE'
                    WHEN 'C' THEN 'CHECK'
                    WHEN 'R' THEN 'FOREIGN KEY'
                    ELSE NULL
                END;
    END get_full_cons_name;
    
    
    FUNCTION parse_check_constraint(json_columns JSON_ARRAY_T, 
                                    json_check_constraint JSON_OBJECT_T) 
                                    RETURN VARCHAR2
    IS
        buff_json_object JSON_OBJECT_T;
    BEGIN
        IF json_columns.get_size != 1 THEN
            RAISE_APPLICATION_ERROR(-20020, 'Wrong input in DDL: 
                "CHECK" expects (1) column name, got (' ||json_columns.get_size || ')');
        END IF;
            buff_json_object := json_check_constraint;
            buff_json_object.put('col_name', json_check_constraint.get_string(0));
        RETURN '(' || parse_simple_condition(buff_json_object) || ')';
    END parse_check_constraint;
    
    
    FUNCTION parse_foreign_key_constraint(json_columns JSON_ARRAY_T, 
                                        json_reference JSON_OBJECT_T) 
                                        RETURN VARCHAR2
    IS
        buff_json_array JSON_ARRAY_T;
    BEGIN
        buff_json_array := json_reference.get_array('columns');
        IF buff_json_array.get_size != json_columns.get_size THEN
            RAISE_APPLICATION_ERROR(-20021, 'Wrong input in DDL: 
                "FOREIGN KEY" expects the same column number. Got source(' 
                || json_columns.get_size || '), reference(' || buff_json_array.get_size || ')');           
        END IF;
        RETURN parse_scalar_array(json_columns) || CHR(10)
        || 'REFERENCES ' || json_reference.get_string('tab_name') 
        || parse_scalar_array(buff_json_array);
    END parse_foreign_key_constraint;
    
    
    FUNCTION parse_outline_constraints_section(json_constraints JSON_ARRAY_T) 
                                                RETURN VARCHAR2
    IS
        res_str VARCHAR2(500);
        buff_str VARCHAR2(20);
        buff_json_object JSON_OBJECT_T;
    BEGIN
        FOR i IN 0..json_constraints.get_size - 1
        LOOP
            buff_json_object := TREAT(json_constraints.get(i) AS JSON_OBJECT_T);
            res_str := res_str || 'CONSTRAINT ' || buff_json_object.get_string('cons_name');
            buff_str := get_full_cons_name(buff_json_object.get_string('cons_type'));
            IF buff_str IS NULL THEN
                RAISE_APPLICATION_ERROR(-20019, 'Unsupported "cons_type" parameter in DDL');
            END IF;
            
            IF buff_str = 'CHECK' THEN
                res_str := res_str || parse_check_constraint(buff_json_object.get_array('columns'), 
                                                        buff_json_object.get_object('comparison')) || ',';
            ELSIF buff_str = 'FOREIGN KEY' THEN
                res_str := res_str 
                    || parse_foreign_key_constraint(buff_json_object.get_array('columns'), 
                                                    buff_json_object.get_object('reference')) || ',';
            END IF;
            res_str := res_str || ' ' || buff_str 
                    || parse_scalar_array(buff_json_object.get_array('columns')) || ',';            
        END LOOP;
        RETURN RTRIM(res_str, ',');
    END parse_outline_constraints_section;

    FUNCTION parse_create_section(json_columns JSON_ARRAY_T, 
                                    json_constraints JSON_ARRAY_T) RETURN VARCHAR2
    IS
        res_str VARCHAR2(500);
    BEGIN
        FOR i IN 0..json_columns.get_size - 1
        LOOP
            res_str := res_str || json_columns.get_string('col_name') || ' ' 
                || json_columns.get_string('data_type') || ' ' 
                || REGEXP_REPLACE(parse_scalar_array(TREAT(json_columns.get('data_type') AS JSON_ARRAY_T)),
                                '\(|,|\)|"', '')
                || ',' || CHR(10);          
        END LOOP;
        res_str := res_str || parse_outline_constraints_section(json_constraints);
        
        RETURN RTRIM(res_str, ',');
    END parse_create_section;
                                    
                                    
    FUNCTION parse_ddl_section(json_query_string JSON_OBJECT_T) RETURN VARCHAR2
    IS
        res_str VARCHAR2(1000);
    BEGIN
        IF NOT json_query_string.has('type') THEN
            RAISE_APPLICATION_ERROR(-20016, 'There is no necessary "type" parameter in DDL');
        END IF;
        IF NOT json_query_string.has('tab_name') THEN
            RAISE_APPLICATION_ERROR(-20017, 'There is no necessary "tab_name" parameter in DDL');
        END IF;
        
        res_str := UPPER(json_query_string.get_string('type')) || ' TABLE ' 
                        || json_query_string.get_string('tab_name');
        
        IF res_str LIKE 'DROP%' THEN
            RETURN res_str;
        ELSIF res_str LIKE 'CREATE%' THEN
            NULL;
        ELSE
            RAISE_APPLICATION_ERROR(-20018, 'Unsupported "type" parameter in DDL');
        END IF;
        res_str := res_str || CHR(10) 
                || '(' || parse_create_section(json_query_string.get_array('columns'),
                                                json_query_string.get_array('outline_constraints')) || ')';
        RETURN res_str;
    END parse_ddl_section;
    
    
    FUNCTION parse_JSON_to_SQL(json_query_string JSON_OBJECT_T) RETURN VARCHAR2
    IS
    BEGIN
        IF json_query_string.has('select') THEN
            RETURN parse_select(json_query_string.get_object('select'));
        ELSIF json_query_string.has('DML') THEN
            RETURN parse_dml_section(json_query_string.get_object('DML'));
        END IF;
        RETURN NULL;
    END parse_JSON_to_SQL;
END json_parser;


BEGIN
    DBMS_OUTPUT.PUT_LINE(REGEXP_REPLACE(json_parser.parse_scalar_array(JSON_ARRAY_T.parse('["asd", "zxc"]')), '\(|,|\)', ''));
END;


DECLARE
    json_query_param VARCHAR2(32000) :=  '{
    "select": {
        "tables": [
            {"tab_name": "tab1",
            "columns": [
                {"col_name": "col1_name", "alias": "alias"},
                {"col_name": "col1_name", "alias": "alias"}
            ]},
            {"tab_name": "tab2",
            "columns": [
                {"col_name": "col1", "alias": "alias"},
                {"col_name": "col2_name", "alias": "alias"}
            ]}
        ],
        "from": [{"tab_name": "tab1", "alias": "alias"}, {"tab_name": "tab2", "alias": "alias"}],
        "where": {
            "and": [
                {"comparison": {
                    "tab_name": "tab1",
                    "col_name": "col_to_compare",
                    "comparator": ">",
                    "value": 5
                    }
                },
                {"comparison": {
                    "tab_name": "tab2",
                    "col_name": "gsa",
                    "comparator": "in",
                    "value": {
                        "select": {
                            "tables": [
                                {"tab_name": "tab1",
                                "columns": [
                                    {"col_name": "col1_name", "alias": "alias"},
                                    {"col_name": "col1_name", "alias": "alias"}
                                ]}
                            ],
                                "from": [{}, {}],
                                "where":{
                                    "or": [
                                        {"comparison": {
                                            "tab_name": "tqbbb",
                                            "col_name": "col_to_compare_in1",
                                            "comparator": ">",
                                            "value": 15
                                            }
                                        },
                                        {"comparison": {
                                            "tab_name": "dhst",
                                            "col_name": "col_to_compare_in2",
                                            "comparator": "<",
                                            "value": 25
                                            }
                                        }
                                    ]
                                }
                            }
                        }
                    }  
                }
            ]
        },
        "join": [
            {"join_type": "full outer",
            "table": {"tab_name": "tab1", "alias": "alias"},
            "on": {
                "comparison": {
                        "tab_name": "tab1",
                        "col_name": "col_to_compare",
                        "comparator": "=",
                        "value": {"tab_name": "tda", "col_name": "coclco"}
                    }    
                }
            },
            {"join_type": "inner",
            "select": {},
            "on": {
                "comment": "/*The same nesting rules as in and|or block*/",
                "comparison": {
                        "tab_name": "tab1",
                        "col_name": "col_to_compare",
                        "comparator": ">",
                        "value": 5
                    }    
                }
            }
        ]
    }
}';
  je JSON_ELEMENT_T;
  jo JSON_OBJECT_T;
BEGIN
    je := JSON_ELEMENT_T.parse(json_query_param);
    jo := TREAT(je AS JSON_OBJECT_T);
    DBMS_OUTPUT.PUT_LINE(json_parser.parse_JSON_to_SQL(TREAT(jo AS JSON_OBJECT_T)));
END;