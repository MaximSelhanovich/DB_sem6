CREATE OR REPLACE FUNCTION parse_table_section(json_query_string JSON_ARRAY_T)
                                                RETURN VARCHAR2
IS
BEGIN
    RETURN json_query_string.to_String();
END parse_table_section;

CREATE OR REPLACE FUNCTION parse_select(json_query_string JSON_OBJECT_T) 
                                            RETURN VARCHAR2
IS
res_str VARCHAR2(32000) := 'SELECT ';
BEGIN
    IF NOT json_query_string.has('tables') THEN
        RAISE_APPLICATION_ERROR(-20001, 'There is now "tables" section');
    END IF;
    res_str := res_str || 
        parse_table_section(TREAT(json_query_string.get('tables') AS JSON_ARRAY_T));
    RETURN res_str;
END parse_select;


CREATE OR REPLACE FUNCTION parse_JSON_to_SQL(json_query_string JSON_OBJECT_T) 
                                            RETURN VARCHAR2
IS
BEGIN
    IF json_query_string.has('select') THEN
        RETURN parse_select(TREAT(json_query_string.get('select') AS JSON_OBJECT_T));
    END IF;
END parse_JSON_to_SQL;


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
    je := JSON_ELEMENT_T.parse(json_query_param);
    jo := treat(je AS JSON_OBJECT_T);
    --jo := TREAT(jo.get('select') AS JSON_OBJECT_T);
    --DBMS_OUTPUT.PUT_LINE(jo.stringify);
    DBMS_OUTPUT.PUT_LINE(parse_JSON_to_SQL(jo));
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
