--TODO: CONSTRAINT CHECK
--TODO: MODIFY COMPARISON OF COLUMS IN TABLE
CREATE OR REPLACE PROCEDURE add_table(schema_name VARCHAR2, 
                                    param_table_name VARCHAR2)
IS
CURSOR get_table IS
    SELECT column_name
    FROM all_tab_columns 
    WHERE owner = schema_name
    AND table_name = param_table_name;
tab_rec get_table%ROWTYPE;
tmp_string VARCHAR2(200) := '';
BEGIN
    DBMS_OUTPUT.PUT_LINE('CREATE TABLE ' || param_table_name || ' (');
    OPEN get_table;
    FETCH get_table INTO tab_rec;
    --WHILE get_table%FOUND 
    LOOP
        tmp_string := get_column_defenition(schema_name, 
                                            param_table_name, 
                                            tab_rec.column_name);
        FETCH get_table INTO tab_rec;
        IF get_table%NOTFOUND THEN
            DBMS_OUTPUT.PUT_LINE(tmp_string);
            EXIT;
        ELSE
            DBMS_OUTPUT.PUT_LINE(tmp_string || ',');
            tmp_string := '';
        END IF;
    END LOOP;
    CLOSE get_table;
    DBMS_OUTPUT.PUT_LINE(');');
END add_table;


CREATE OR REPLACE PROCEDURE check_tables(dev_schema_name VARCHAR2,
                                        prod_schema_name VARCHAR2)
IS
CURSOR get_table_names IS
    SELECT * FROM 
        (SELECT table_name dev_name FROM all_tables
        WHERE owner = 'C##DEVELOPMENT') dev
        FULL OUTER JOIN
        (SELECT table_name prod_name FROM all_tables 
        WHERE owner = 'C##PRODUCTION') prod
        ON dev.dev_name = prod.prod_name;
BEGIN
    FOR rec IN get_table_names
    LOOP
        IF rec.dev_name IS NULL THEN
            DBMS_OUTPUT.PUT_LINE('DROP TABLE ' || rec.prod_name || ';');
            CONTINUE;
        END IF;
        IF rec.prod_name IS NULL THEN
            add_table(dev_schema_name, rec.dev_name);
            CONTINUE;
        END IF;
        check_table_structure(dev_schema_name, prod_schema_name, rec.dev_name);
    END LOOP;
END check_tables;

CREATE OR REPLACE FUNCTION get_sequence(schema_name VARCHAR2, 
                                        param_sequence_name VARCHAR2)
                                        RETURN VARCHAR2
IS
min_val NUMBER;
max_val NUMBER;
inc_by NUMBER;
gen_type VARCHAR2(10);
seq_string VARCHAR2(100) := 'GENERATED';
BEGIN
    SELECT alls.min_value, alls.max_value, 
            alls.increment_by, atic.generation_type
    INTO min_val, max_val, inc_by, gen_type
    FROM all_sequences alls
    INNER JOIN all_tab_identity_cols atic
    ON alls.sequence_name = atic.sequence_name 
    WHERE owner = schema_name AND alls.sequence_name = param_sequence_name;
    
    seq_string := seq_string || ' ' || gen_type || ' AS IDENTITY';
    IF min_val != 1 THEN
        seq_string := seq_string || ' START WITH ' || min_val;
    END IF;
    IF inc_by != 1 THEN
        seq_string := seq_string || ' INCREMENT BY ' || inc_by;
    END IF;
    IF max_val != 9999999999999999999999999999 THEN
        seq_string := seq_string || ' MAXVALUE ' || max_val;
    END IF;
    RETURN seq_string;
END get_sequence;


SELECT * FROM
    (SELECT table_name, column_name, data_type, data_length, data_precision, data_scale, nullable, data_default
    FROM all_tab_columns
    WHERE owner = 'C##DEVELOPMENT' AND table_name = UPPER('MyTable')) tab1
    INNER JOIN
    (SELECT column_name, constraint_name, position
    FROM all_cons_columns
    WHERE owner = 'C##DEVELOPMENT' AND table_name = UPPER('MyChildTable')) tab2
    ON tab1.column_name = tab2.column_name
    INNER JOIN 
    (SELECT constraint_name, constraint_type, r_constraint_name, delete_rule, generated
    FROM all_constraints
    WHERE owner = 'C##DEVELOPMENT' AND table_name = UPPER('MyChildTable')
    AND constraint_type = 'P') tab3
    ON tab2.constraint_name = tab3.constraint_name;



SELECT * FROM all_tab_columns 
WHERE owner = 'C##DEVELOPMENT' AND table_name = UPPER('MyChildTable'); /




SELECT * from all_constraints 
WHERE OWNER = 'C##DEVELOPMENT' AND table_name = UPPER('MyChildTable'); /
SELECT *  FROM all_cons_columns 
WHERE OWNER = 'C##DEVELOPMENT' AND table_name = UPPER('MyChildTable');   

/*ALL_CONSTRAINTS
ALL_CONS_COLUMNS
ALL_IDENTIFIERS
ALL_SEQUENCES
ALL_TAB_COLS
ALL_TAB_COLUMNS
ALL_TAB_COL_STATISTICS*/

SELECT *  FROM all_cons_columns 
WHERE OWNER = 'C##DEVELOPMENT' AND table_name = UPPER('MyChildTable');
    
SELECT * FROM all_cons_columns
WHERE owner = schema_name AND table_name = UPPER('MyChildTable');

CREATE OR REPLACE FUNCTION get_constraint(schema_name VARCHAR2,
                                            param_constraint_name VARCHAR2)
                                            RETURN VARCHAR2
IS
CURSOR get_cols_in_cons IS
    SELECT column_name FROM all_cons_columns
    WHERE owner = schema_name AND constraint_name = param_constraint_name
    ORDER BY POSITION;

cons_type VARCHAR2(1);
tmp_str VARCHAR2(100);
cons_string VARCHAR2(200);
BEGIN
    SELECT constraint_type, search_condition INTO cons_type, tmp_str
    FROM all_constraints 
    WHERE owner = schema_name AND constraint_name = param_constraint_name;
        cons_string := cons_string || 'CONSTRAINT ' || param_constraint_name;
    CASE cons_type
        WHEN 'R' THEN 
            RETURN get_foreign_key_constraint(schema_name, param_constraint_name);
        WHEN 'C' THEN
            RETURN cons_string || ' CHECK (' || tmp_str || ')';
        WHEN 'U' THEN
            cons_string := cons_string || ' UNIQUE (';
        WHEN 'U' THEN
            cons_string := cons_string || ' PRIMARY KEY (';
        ELSE RETURN NULL;
    END CASE;
    FOR rec in get_cols_in_cons
    LOOP
        cons_string := cons_string || rec.column_name || ', ';
    END LOOP;
    cons_string := RTRIM(cons_string, ', ');
    cons_string := cons_string || ')';
    RETURN cons_string;
END get_constraint;

CREATE OR REPLACE FUNCTION get_foreign_key_constraint(schema_name VARCHAR2,
                                                    param_constraint_name VARCHAR2)
                                                    RETURN VARCHAR2
IS
CURSOR ref_params IS
    SELECT r_owner, r_constraint_name, delete_rule FROM all_constraints 
    WHERE OWNER = schema_name
    AND constraint_name = param_constraint_name AND constraint_type = 'R';
    
CURSOR refers_columns IS
    SELECT * FROM all_cons_columns
    WHERE owner = schema_name AND constraint_name = param_constraint_name
    ORDER BY POSITION;
    
CURSOR referred_columns(ref_owner VARCHAR2, ref_cons_name VARCHAR2) IS
    SELECT * FROM all_cons_columns
    WHERE owner = ref_owner AND constraint_name = ref_cons_name
    ORDER BY POSITION;

ref_owner VARCHAR2(100);
ref_cons_name VARCHAR2(100);
del_rule VARCHAR2(20);

first_write NUMBER := 1;
cons_string VARCHAR2(300);
BEGIN
    OPEN ref_params;
    FETCH ref_params INTO ref_owner, ref_cons_name, del_rule;
    CLOSE ref_params;
    cons_string := cons_string || 'CONSTRAINT ' 
                || param_constraint_name || ' FOREIGN KEY (';
    FOR rec IN refers_columns
    LOOP
        cons_string := cons_string || rec.column_name || ', ';
    END LOOP;
    cons_string := RTRIM(cons_string, ', ');
    cons_string := cons_string || ') REFERENCES ';
    
    FOR rec IN referred_columns(ref_owner, ref_cons_name)
    LOOP
        IF first_write = 1 THEN
            cons_string := cons_string || rec.table_name || ' (';
            first_write := 0;
        END IF;
        cons_string := cons_string || rec.column_name || ', ';
    END LOOP;
    cons_string := RTRIM(cons_string, ', ');
    cons_string := cons_string || ')';
    IF del_rule != 'NO ACTION' THEN
        cons_string := cons_string || ' ON DELETE ' || del_rule;
    END IF;
    RETURN cons_string;
END get_foreign_key_constraint;


CREATE OR REPLACE FUNCTION get_inline_constraints(schema_name VARCHAR2,
                                                param_table_name VARCHAR2,
                                                param_column_name VARCHAR2)
                                                RETURN VARCHAR2 IS
CURSOR get_constraints IS
    SELECT * FROM 
        (SELECT constraint_name FROM all_cons_columns
        WHERE owner = 'C##DEVELOPMENT' AND table_name = UPPER('MyChildTable')
        AND column_name = UPPER('MYTABLE_ID')) acc
        INNER JOIN
        (SELECT constraint_name, constraint_type, search_condition FROM all_constraints
        WHERE owner = 'C##DEVELOPMENT' AND table_name = UPPER('MyChildTable')
        AND generated = 'GENERATED NAME') allc
        ON acc.constraint_name = allc.constraint_name;
cons_string VARCHAR2(100);
BEGIN
    FOR rec IN get_constraints
    LOOP
        CASE rec.constraint_type
            WHEN 'P' THEN cons_string := cons_string || ' PRIMARY KEY';
            WHEN 'U' THEN cons_string := cons_string || ' UNIQUE';
            WHEN 'C' THEN
                IF rec.search_condition NOT LIKE '% IS NOT NULL' THEN
                    cons_string := cons_string || ' CHECK(' || rec.search_condition || ')';
                END IF;
            ELSE NULL;
        END CASE;
    END LOOP;
    RETURN cons_string;
END get_inline_constraints;

CREATE OR REPLACE FUNCTION get_column_defenition(schema_name VARCHAR2,
                                                param_table_name VARCHAR2,
                                                param_column_name VARCHAR2) 
                                                RETURN VARCHAR2 IS
CURSOR get_column IS
    SELECT table_name, column_name, data_type, data_length, 
            data_precision, data_scale, nullable, data_default
    FROM all_tab_columns
    WHERE owner = schema_name 
    AND table_name = param_table_name AND column_name = param_column_name;
column_defenition VARCHAR2(300);
BEGIN
    --use loop for a single row just for avoiding creating variables
    FOR rec IN get_column
    LOOP
        column_defenition := column_defenition || rec.column_name 
                            || ' ' || rec.data_type;
        IF rec.data_type NOT LIKE '%(%)' THEN
            column_defenition := column_defenition 
                                || '(' || rec.data_length || ')';
        END IF;
        IF rec.nullable = 'N' THEN
            column_defenition := column_defenition || ' NOT NULL'; 
        END IF;
        column_defenition := column_defenition 
                            || get_inline_constraints(schema_name, 
                                                    param_table_name, 
                                                    param_column_name);
        IF rec.data_default IS NULL THEN
            CONTINUE;
        END IF;
        IF rec.data_default LIKE '%.nextval' THEN
            column_defenition := column_defenition 
                                || ' ' || get_sequence(schema_name, 
                                    REGEXP_SUBSTR (rec.data_default, '(ISEQ\$\$_\d+)'));
            CONTINUE;
        END IF;
        column_defenition := column_defenition 
                            || ' DEFAULT ' || rec.data_default;
    END LOOP;
    RETURN column_defenition;
END get_column_defenition;


CREATE OR REPLACE PROCEDURE check_table_structure(dev_schema_name VARCHAR2,
                                                    prod_schema_name VARCHAR2,
                                                    param_table_name VARCHAR2)
IS
CURSOR get_columns IS
    SELECT * FROM 
        (SELECT column_name dev_name FROM all_tab_columns
        WHERE owner = 'C##DEVELOPMENT' AND table_name = 'MYTABLE') dev
        FULL OUTER JOIN
        (SELECT column_name prod_name FROM all_tab_columns
        WHERE owner = 'C##PRODUCTION' AND table_name = 'MYTABLE') prod
        ON dev.dev_name = prod.prod_name;
BEGIN
    FOR rec IN get_columns
    LOOP
        IF rec.dev_name IS NULL THEN
            DBMS_OUTPUT.PUT_LINE('ALTER TABLE ' || param_table_name 
                                || 'DROP COLUMN ' || rec.prod_name || ';');
            CONTINUE;
        END IF;
        IF rec.prod_name IS NULL THEN
            DBMS_OUTPUT.PUT_LINE('ALTER TABLE ' 
                                    || param_table_name || 'ADD ' 
                                    || get_column_defenition(dev_schema_name, 
                                                            param_table_name, 
                                                            rec.dev_name));
            CONTINUE;
        END IF;
        --temporarry solution, later only different stats should be MODIFIED
        IF get_column_defenition(dev_schema_name, param_table_name, rec.dev_name)
            !=
            get_column_defenition(prod_schema_name, param_table_name, rec.prod_name)
        THEN
            DBMS_OUTPUT.PUT_LINE('ALTER TABLE ' || param_table_name 
                                || 'DROP COLUMN ' || rec.prod_name || ';'); 
            DBMS_OUTPUT.PUT_LINE('ALTER TABLE ' 
                                    || param_table_name || 'ADD ' 
                                    || get_column_defenition(dev_schema_name, 
                                                            param_table_name, 
                                                            rec.dev_name));
        END IF;
    END LOOP;
END check_table_structure;

select * from all_constraints WHERE OWNER = 'C##DEVELOPMENT'; /
SELECT *  FROM all_cons_columns WHERE OWNER = 'C##DEVELOPMENT';

--DROP VIEW parent_child_view;
CREATE OR REPLACE VIEW parent_child_view AS
SELECT pk.owner      parent_owner,
       pk.table_name parent_table,
       fk.owner      child_owner,
       fk.table_name child_table
FROM all_constraints fk,
     all_constraints pk
WHERE pk.owner = fk.r_owner
    AND pk.constraint_name = fk.r_constraint_name
    AND fk.constraint_type = 'R'
    AND pk.owner = 'C##DEVELOPMENT';


SELECT * FROM 
    (SELECT pk.owner      parent_owner,
       pk.table_name parent_table,
       fk.owner      child_owner,
       fk.table_name child_table
FROM all_constraints fk
INNER JOIN  all_constraints pk
ON pk.owner = fk.r_owner
    AND pk.constraint_name = fk.r_constraint_name
WHERE fk.constraint_type = 'R'
    AND pk.owner = 'C##DEVELOPMENT');


CREATE OR REPLACE PROCEDURE circular_check
IS
CURSOR parent_child_cursor IS 
    SELECT pk.owner parent_owner,
       pk.table_name parent_table,
       fk.owner child_owner,
       fk.table_name child_table
    FROM all_constraints fk,
        all_constraints pk
    WHERE pk.owner = fk.r_owner
        AND pk.constraint_name = fk.r_constraint_name
        AND fk.constraint_type = 'R'
        AND pk.owner = 'C##DEVELOPMENT';
message VARCHAR2(200);
BEGIN
    FOR rec IN parent_child_cursor
    LOOP
        message := rec.parent_table || '<-' || rec.child_table;
        DBMS_OUTPUT.PUT_LINE(recursive_part_circular_check(rec.parent_table, 
                                                            rec.child_table,
                                                            message));
        DBMS_OUTPUT.PUT_LINE(message);
    END LOOP;
END circular_check;


CREATE OR REPLACE FUNCTION recursive_part_circular_check(start_table VARCHAR2, 
                                          step_table VARCHAR2,
                                          message IN OUT VARCHAR2) RETURN NUMBER
IS
    check_val VARCHAR2(100);
BEGIN
    SELECT child_table INTO check_val FROM parent_child_view 
    WHERE parent_table = step_table AND ROWNUM = 1;
    IF start_table = check_val THEN
        message := message || '<-' || start_table;
        RETURN 1;
    ELSE
        message := message || '<-' || check_val;
        RETURN recursive_part_circular_check(start_table, check_val, message);
    END IF;
EXCEPTION
    WHEN NO_DATA_FOUND THEN
        --message := 'no cycle';
        RETURN 0;
END recursive_part_circular_check;

-------------------------------------------------------
--CALLABLES SECTION

SELECT * FROM all_procedures
WHERE owner = 'C##DEVELOPMENT' 
OR owner = 'C##PRODUCTION';

SELECT * FROM all_objects
WHERE owner = 'C##DEVELOPMENT' 
OR owner = 'C##PRODUCTION';

SELECT * FROM all_source
WHERE owner = 'C##DEVELOPMENT' 
OR owner = 'C##PRODUCTION';

SELECT * FROM all_identifiers
WHERE owner = 'C##DEVELOPMENT' 
OR owner = 'C##PRODUCTION';

CREATE OR REPLACE PROCEDURE add_object(dev_schema_name VARCHAR2,
                                        object_name VARCHAR2,
                                        object_type VARCHAR2)
IS
CURSOR get_object IS
    SELECT text FROM all_source
    WHERE owner = dev_schema_name 
    AND name = object_name AND type = object_type;
    
check_var VARCHAR2(100);
BEGIN
    OPEN get_object;
    FETCH get_object INTO check_var;
    CLOSE get_object;
    IF check_var IS NULL THEN
        RETURN;
    END IF;
    DBMS_OUTPUT.PUT_LINE('CREATE OR REPLACE ');
    FOR rec IN get_object
    LOOP
        DBMS_OUTPUT.PUT_LINE(rec.text);
    END LOOP;
END add_object;

CREATE OR REPLACE PROCEDURE check_callables(dev_schema_name VARCHAR2,
                                            prod_schema_name VARCHAR2,
                                            param_object_type VARCHAR2)
IS
CURSOR get_callable_names IS
    SELECT dev_name, prod_name
    FROM 
        (SELECT object_name dev_name FROM all_objects 
        WHERE owner = dev_schema_name AND object_type = param_object_type) dev
    FULL JOIN
        (SELECT object_name prod_name FROM all_objects
        WHERE owner = prod_schema_name AND object_type = param_object_type) prod
    ON dev.dev_name = prod.prod_name;

BEGIN
    FOR rec IN get_callable_names 
    LOOP
        IF rec.dev_name IS NULL THEN
            DBMS_OUTPUT.PUT_LINE('DROP ' || param_object_type || ' ' 
                                || rec.prod_name || ';');
            CONTINUE;
        END IF;
        
        IF rec.prod_name IS NULL OR
            get_callable_text(dev_schema_name, param_object_type, rec.dev_name) 
            !=
            get_callable_text(prod_schema_name, param_object_type, rec.prod_name)
        THEN
            add_object(dev_schema_name, rec.dev_name, param_object_type);
        END IF;
    END LOOP;
END check_callables;

CREATE OR REPLACE FUNCTION get_callable_text(schema_name VARCHAR2,
                                            object_type VARCHAR2,
                                            object_name VARCHAR2) 
                                            RETURN VARCHAR2
IS
CURSOR get_call_text IS
    SELECT 
        UPPER(TRIM(' ' FROM (TRANSLATE(text, CHR(10) || CHR(13), ' ')))) object_text 
    FROM all_source
    WHERE owner = schema_name AND name = object_name
    AND type = object_type AND text != chr(10);

callable_text VARCHAR2(32000) := '';
BEGIN
    FOR rec IN get_call_text
    LOOP
        callable_text := callable_text || rec.object_text;
    END LOOP;
    RETURN callable_text;
END get_callable_text;

BEGIN
    check_callables('C##DEVELOPMENT', 'C##PRODUCTION', 'FUNCTION');
END;

----------------------------------------------------
--PACKAGES SECTION
CREATE OR REPLACE PROCEDURE check_packages(dev_schema_name VARCHAR2,
                                            prod_schema_name VARCHAR2)
IS
CURSOR get_package_names IS
    SELECT dev_name, prod_name
    FROM 
        (SELECT object_name dev_name FROM all_objects 
        WHERE owner = dev_schema_name AND object_type = 'PACKAGE') dev
    FULL JOIN
        (SELECT object_name prod_name FROM all_objects
        WHERE owner = prod_schema_name AND object_type = 'PACKAGE') prod
    ON dev.dev_name = prod.prod_name;
BEGIN
    FOR rec IN get_package_names
    LOOP
        IF rec.prod_name IS NULL THEN
            add_object(dev_schema_name, rec.dev_name, 'PACKAGE');
            add_object(dev_schema_name, rec.dev_name, 'PACKAGE BODY');
            CONTINUE;
        END IF ;
        IF rec.dev_name IS NULL THEN
            DBMS_OUTPUT.PUT_LINE('DROP PACKAGE ' || rec.prod_name || ';');
            CONTINUE;
        END IF;
        IF get_object_from_package(dev_schema_name, rec.dev_name, 
                                    'PACKAGE', rec.dev_name)
            !=
            get_object_from_package(prod_schema_name, rec.prod_name, 
                                    'PACKAGE', rec.prod_name) 
        THEN
            add_object(dev_schema_name, rec.dev_name, 'PACKAGE');
        END IF;
        check_package_body(dev_schema_name, prod_schema_name, rec.dev_name);
    END LOOP;
END;

CREATE OR REPLACE PROCEDURE check_package_body(dev_schema_name VARCHAR2,
                                                prod_schema_name VARCHAR2,
                                                package_name VARCHAR2) IS
dev_name VARCHAR2(200);
prod_name VARCHAR2(200);
BEGIN
    SELECT object_name INTO dev_name FROM all_objects
    WHERE owner = dev_schema_name 
    AND object_type = 'PACKAGE BODY' AND object_name = package_name;

    SELECT object_name INTO prod_name FROM all_objects
    WHERE owner = prod_schema_name 
    AND object_type = 'PACKAGE BODY' AND object_name = package_name;
    
    IF dev_name IS NULL AND prod_name IS NULL THEN
        RETURN;
    END IF;
    IF dev_name IS NULL THEN
        DBMS_OUTPUT.PUT_LINE('DROP PACKAGE BODY ' || prod_name || ';');
        RETURN;
    END IF;
    IF prod_name IS NULL 
        OR is_same_package_bodies(dev_schema_name, 
                                    prod_schema_name, 
                                    package_name) = 0 THEN
        add_object(dev_schema_name, dev_name, 'PACKAGE BODY');
    END IF;
END check_package_body;    

--returns 1 if packages are the same
CREATE OR REPLACE FUNCTION is_same_package_bodies(dev_schema_name VARCHAR2,
                                                   prod_schema_name VARCHAR2,
                                                   package_body_name VARCHAR2) 
                                                   RETURN NUMBER
IS
CURSOR get_package_callable_names IS
    SELECT dev_name, dev_type, prod_name, prod_type
    FROM 
        (SELECT name dev_name, type dev_type FROM all_identifiers 
        WHERE owner = 'C##DEVELOPMENT' AND object_type = 'PACKAGE BODY'
        AND type IN ('PROCEDURE', 'FUNCTION') AND usage = 'DEFINITION') dev
    FULL JOIN
        (SELECT name prod_name, type prod_type FROM all_identifiers
        WHERE owner = 'C##PRODUCTION'  AND object_type = 'PACKAGE BODY'
        AND type IN ('PROCEDURE', 'FUNCTION') AND usage = 'DEFINITION') prod
    ON dev.dev_name = prod.prod_name;

BEGIN
    FOR rec IN get_package_callable_names
    LOOP
        IF rec.dev_name IS NULL OR rec.prod_name IS NULL THEN
            RETURN 0;
        END IF;
        IF get_object_from_package(dev_schema_name, package_body_name, 
                                        rec.dev_type, rec.dev_name) 
            !=
            get_object_from_package(prod_schema_name, package_body_name, 
                                        rec.prod_type, rec.prod_name) THEN
            RETURN 0;
        END IF;
    END LOOP ;
    RETURN 1;
END is_same_package_bodies;

--return object from package body as a single string for next comparison
CREATE OR REPLACE FUNCTION get_object_from_package(schema_name VARCHAR2,
                                                    package_name VARCHAR2,
                                                    object_type VARCHAR2,
                                                    object_name VARCHAR2) 
                                                    RETURN VARCHAR2
IS
res_obj_type varchar2(20) :=
    CASE object_type 
        WHEN 'PACKAGE' THEN object_type
        ELSE 'PACKAGE BODY' END;

CURSOR get_object IS
    SELECT owner, 
        UPPER(TRIM(' ' FROM (TRANSLATE(text, CHR(10) || CHR(13), ' ')))) object_text 
    FROM all_source
    WHERE owner = schema_name AND name = package_name
    AND type = res_obj_type AND text != chr(10);

obj_text VARCHAR2(32676) := '';
write_flag BOOLEAN := FALSE;
BEGIN
    FOR rec IN get_object
    LOOP
        IF REGEXP_LIKE(rec.object_text, '^' || UPPER(object_type) || '*', 'ix') THEN
            write_flag := TRUE;
            obj_text := obj_text || rec.object_text;
            CONTINUE;
        END IF;
        IF write_flag THEN
            obj_text := obj_text || rec.object_text;
        END IF;
        IF NOT REGEXP_LIKE(obj_text, '(^' || object_type 
                                    || ')*(' ||object_name  || '*)', 
                           'ix') THEN
            write_flag := FALSE;
            obj_text := '';
        END IF;
        IF REGEXP_LIKE(obj_text,'END ' || UPPER(object_name) || ';?$') THEN
            EXIT;
        END IF;
    END LOOP;
    RETURN obj_text;
END get_object_from_package;


-----------------------------------------------------
--INDEX SECTIOM
CREATE OR REPLACE FUNCTION get_index_string(schema_name VARCHAR2,
                                            param_index_name VARCHAR2) 
                                            RETURN VARCHAR2
IS
CURSOR get_index IS
    SELECT aic.index_name, aic.table_name, 
            aic.column_name, aic.column_position, ai.uniqueness 
    FROM all_ind_columns aic
    INNER JOIN all_indexes ai
    ON ai.index_name = aic.index_name AND ai.owner = aic.index_owner
    WHERE aic.index_owner = schema_name AND aic.index_name = param_index_name
    ORDER BY aic.column_position;
    
index_rec get_index%ROWTYPE;
index_string VARCHAR2(200);
BEGIN
    OPEN get_index;
    FETCH get_index INTO index_rec;
    index_string := index_string || ' ' || index_rec.table_name || '(';
    WHILE get_index%FOUND 
    LOOP
        index_string := index_string || index_rec.column_name || ', ';
        FETCH get_index INTO index_rec;
    END LOOP;
    CLOSE get_index;
    index_string := RTRIM(index_string, ', ');
    index_string := index_string || ')';
    RETURN index_string;
END get_index_string;

CREATE OR REPLACE PROCEDURE check_indexes(dev_schema_name VARCHAR2,
                                            prod_schema_name VARCHAR2)
IS
CURSOR get_indexes IS
    SELECT DISTINCT dev_uniqueness, dev_index_name, prod_uniqueness, prod_index_name 
    FROM
        (SELECT ai.index_name dev_index_name, ai.index_type dev_index_type, 
                ai.table_name dev_table_name, ai.table_type dev_table_type, 
                ai.uniqueness dev_uniqueness, aic.column_name dev_column_name, 
                aic.column_position dev_column_position
        FROM all_indexes ai
        INNER JOIN all_ind_columns aic
        ON ai.index_name = aic.index_name AND ai.owner = aic.index_owner
        WHERE ai.owner = 'C##DEVELOPMENT') dev
    FULL OUTER JOIN
        (SELECT ai.index_name prod_index_name, ai.index_type prod_index_type, 
                ai.table_name prod_table_name, ai.table_type prod_table_type, 
                ai.uniqueness prod_uniqueness, aic.column_name prod_column_name, 
                aic.column_position prod_column_position
        FROM all_indexes ai
        INNER JOIN all_ind_columns aic
        ON ai.index_name = aic.index_name AND ai.owner = aic.index_owner
        WHERE ai.owner = 'C##PRODUCTION') prod
    ON dev.dev_table_name = prod.prod_table_name 
    AND dev.dev_column_name = prod.prod_column_name;

res_index_name VARCHAR2(200);
BEGIN
    FOR rec IN get_indexes
    LOOP
        IF rec.prod_index_name IS NULL THEN
            res_index_name := rec.dev_index_name;
            IF rec.dev_index_name LIKE 'SYS_%' THEN
                res_index_name := 'GENERATED_' || rec.dev_index_name;
            END IF;
            DBMS_OUTPUT.PUT_LINE('CREATE ' || rec.dev_uniqueness 
                                || ' INDEX ' || res_index_name 
                                || get_index_string(dev_schema_name, rec.dev_index_name));
            CONTINUE;
        END IF;
        
        IF rec.dev_index_name IS NULL THEN
            DBMS_OUTPUT.PUT_LINE('DROP INDEX ' || rec.prod_index_name || ';');
            CONTINUE;
        END IF;
        IF get_index_string(dev_schema_name, rec.dev_index_name)
            !=
            get_index_string(prod_schema_name, rec.prod_index_name)
            OR rec.dev_uniqueness != rec.prod_uniqueness THEN
            DBMS_OUTPUT.PUT_LINE('DROP INDEX ' || rec.prod_index_name || ';');
            DBMS_OUTPUT.PUT_LINE('CREATE '|| rec.dev_uniqueness ||' INDEX ' 
                                || rec.prod_index_name 
                                || get_index_string(dev_schema_name, rec.dev_index_name) ||';');
        END IF;
    END LOOP;
END check_indexes;

SELECT *
FROM all_indexes
WHERE owner = 'C##DEVELOPMENT'; /

SELECT *
FROM all_ind_columns
WHERE index_owner = 'C##DEVELOPMENT';