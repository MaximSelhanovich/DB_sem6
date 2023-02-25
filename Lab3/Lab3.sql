CREATE OR REPLACE PROCEDURE check_table_structure(dev_schema_name VARCHAR2,
                                                prod_schema_name VARCHAR2,
                                                check_table_name VARCHAR2) 
IS
CURSOR dev_table_columns IS 
    SELECT TABLE_NAME, COLUMN_NAME FROM ALL_TAB_COLUMNS 
    WHERE owner = dev_schema_name 
    AND table_name = check_table_name;
    
CURSOR prod_table_columns IS 
    SELECT TABLE_NAME, COLUMN_NAME FROM ALL_TAB_COLUMNS 
    WHERE owner = prod_schema_name 
    AND table_name = check_table_name;
existence_check BOOLEAN;
BEGIN
    FOR dev_rec IN dev_table_columns
    LOOP
        FOR prod_rec in prod_table_columns 
        LOOP
            IF dev_rec.COLUMN_NAME = prod_rec.COLUMN_NAME THEN
                existence_check := TRUE;
                EXIT;
            END IF;
        END LOOP;
        IF NOT existence_check THEN
            DBMS_OUTPUT.PUT_LINE('THERE IS NO COLUMN (' || dev_rec.COLUMN_NAME ||
                                ') IN TABLE: '|| prod_schema_name || 
                                '.' || check_table_name);
        END IF;
        existence_check := FALSE;
    END LOOP;
END check_table_structure;

CREATE OR REPLACE PROCEDURE check_tables(dev_schema_name VARCHAR2,
                                        prod_schema_name VARCHAR2)
IS
CURSOR dev_tables IS 
    SELECT table_name FROM all_tables 
    WHERE owner = dev_schema_name;
    
CURSOR prod_tables IS 
    SELECT table_name FROM all_tables 
    WHERE owner = prod_schema_name;
existence_check BOOLEAN;
BEGIN
    FOR dev_rec IN dev_tables
    LOOP
        FOR prod_rec in prod_tables
        LOOP
            IF dev_rec.table_name = prod_rec.table_name THEN
                existence_check := TRUE;
                EXIT;
            END IF;
        END LOOP;
        IF NOT existence_check THEN
            DBMS_OUTPUT.PUT_LINE('THERE IS NO table (' || dev_rec.TABLE_NAME ||
                                ') IN SCHEMA: '|| prod_schema_name);
        END IF;
        existence_check := FALSE;
    END LOOP;
END check_tables;

CREATE OR REPLACE PROCEDURE reverse_check_table_structure(dev_schema_name VARCHAR2,
                                                        prod_schema_name VARCHAR2,
                                                        check_table_name VARCHAR2) 
IS
CURSOR dev_tables IS 
    SELECT table_name FROM all_tables 
    WHERE owner = dev_schema_name;
    
CURSOR prod_tables IS 
    SELECT table_name FROM all_tables 
    WHERE owner = prod_schema_name;
existence_check BOOLEAN;
BEGIN
    FOR prod_rec IN prod_tables
    LOOP
        FOR dev_rec in  dev_tables
        LOOP
            IF prod_rec.table_name = dev_rec.table_name THEN
                existence_check := TRUE;
                EXIT;
            END IF;
        END LOOP;
        IF NOT existence_check THEN
            DBMS_OUTPUT.PUT_LINE('THERE IS NO table (' || prod_rec.TABLE_NAME ||
                                ') IN SCHEMA: '|| dev_schema_name);
        END IF;
        existence_check := FALSE;
    END LOOP;
END reverse_check_table_structure;

select * from all_constraints WHERE OWNER = 'C##DEVELOPMENT'; /
SELECT *  FROM all_cons_columns WHERE OWNER = 'C##DEVELOPMENT';

BEGIN
    check_tables('C##DEVELOPMENT', 'C##PRODUCTION');
END;

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

SELECT * FROM parent_child_view;


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


BEGIN
    DBMS_OUTPUT.PUT_LINE('START');
    circular_check;
END;


-------------------------------------------------------

SELECT * FROM all_procedures
WHERE owner = 'C##DEVELOPMENT' 
OR owner = 'C##PRODUCTION';

SELECT * FROM all_objects
WHERE owner = 'C##DEVELOPMENT' 
OR owner = 'C##PRODUCTION';

SELECT * FROM all_source
WHERE owner = 'C##DEVELOPMENT' 
OR owner = 'C##PRODUCTION';


CREATE OR REPLACE PROCEDURE complement_callable_differences(dev_schema_name VARCHAR2,
                                                            callable_name VARCHAR2)
IS
CURSOR callable_to_write IS
    SELECT text FROM all_source
    WHERE owner = dev_schema_name
    AND name = callable_name;
BEGIN
    FOR rec IN callable_to_write
    LOOP
        DBMS_OUTPUT.PUT_LINE(rec.text);
    END LOOP;
END complement_callable_differences;

CREATE OR REPLACE PROCEDURE check_callables(dev_schema_name VARCHAR2,
                                            prod_schema_name VARCHAR2,
                                            type_name VARCHAR2) 
IS
CURSOR callable_check(callable_name VARCHAR2) IS
    SELECT
    dev.owner || '.' || dev.name dev_name,
    prod.owner || '.' || prod.name prod_name,
    dev.text dev_text, prod.text prod_text
    FROM all_source dev
    FULL OUTER JOIN 
        (SELECT owner, line, text, name 
        FROM all_source 
        WHERE owner = prod_schema_name AND type = type_name) prod
    ON dev.name = prod.name AND dev.LINE = prod.LINE
    WHERE dev.type = type_name AND dev.owner = dev_schema_name
    AND dev.name = callable_name;
    
CURSOR callable_names IS
    SELECT DISTINCT object_name FROM all_procedures 
    WHERE object_type = type_name 
    AND (owner = dev_schema_name OR owner = prod_schema_name);
BEGIN
    FOR call_rec IN callable_names
    LOOP
        FOR rec IN callable_check(call_rec.object_name)
        LOOP
            IF rec.prod_text IS NULL OR UPPER(rec.dev_text) != UPPER(rec.prod_text) THEN
                complement_callable_differences(dev_schema_name, call_rec.object_name);
                EXIT;
            END IF;
        END LOOP;
    END LOOP;
    drop_callables(dev_schema_name, prod_schema_name, type_name);
END check_callables;

BEGIN
    check_callables('C##DEVELOPMENT', 'C##PRODUCTION', 'FUNCTION');
END;

CREATE OR REPLACE PROCEDURE drop_callables(dev_schema_name VARCHAR2,
                                            prod_schema_name VARCHAR2,
                                            type_name VARCHAR2) 
IS
CURSOR to_drop IS
    (SELECT object_name FROM all_procedures 
    WHERE owner = prod_schema_name AND object_type = type_name)
    MINUS
    (SELECT object_name FROM all_procedures 
    WHERE owner = dev_schema_name AND object_type = type_name);
BEGIN
    FOR rec IN to_drop
    LOOP
        DBMS_OUTPUT.PUT_LINE('DROP ' || type_name || ' ' || rec.object_name);
    END LOOP;
END drop_callables;