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
