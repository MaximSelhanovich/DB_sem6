DROP TABLE MyTable;

select * from dba_users;

CREATE TABLE MyTable 
(
    id NUMBER GENERATED ALWAYS as IDENTITY(START with 1 INCREMENT by 1) NOT NULL PRIMARY KEY,
    val NUMBER,
    constraint uint_id check (id between 0 and 4294967295)
);

BEGIN
    FOR i IN 1..10 LOOP
        INSERT INTO MyTable(val) VALUES (DBMS_RANDOM.RANDOM());
    END LOOP;
END;


SELECT * FROM MyTable WHERE ID=4;

DROP FUNCTION even_odd_check;
CREATE OR REPLACE FUNCTION even_odd_check RETURN VARCHAR2 IS
    even_num SMALLINT := 0;
    odd_num SMALLINT := 0;
BEGIN
    FOR rec IN (SELECT val FROM MyTable)
    LOOP
        IF MOD(rec.val, 2) = 0 THEN
            even_num := even_num + 1;
        ELSE 
            odd_num := odd_num + 1;
        END IF;
    END LOOP;
    
    IF even_num > odd_num THEN
        RETURN 'TRUE';
    ELSIF odd_num > even_num THEN
        RETURN 'FALSE';
    ELSE
        RETURN 'EQUAL ';
    END IF;
END even_odd_check;

BEGIN
   DBMS_OUTPUT.put_line(even_odd_check());
END;

DROP PROCEDURE task_4;
CREATE OR REPLACE PROCEDURE task_4 IS
    valu VARCHAR2(10);
    n NUMBER;
    bad_integer EXCEPTION;
BEGIN
    valu := '&valu';
    IF NOT is_integer(valu) OR TO_NUMBER(valu) < 0 THEN
        RAISE bad_integer;
    END IF;
    --SELECT val INTO n FROM MyTable WHERE MyTable.ID = TO_NUMBER(val);
    DBMS_OUTPUT.put_line('INSERT(' || valu || ');');

    SELECT VAL INTO n FROM MyTable WHERE ID=TO_NUMBER(valu);

    IF n IS NULL THEN
        RAISE bad_integer;
    END IF;    
    
    DBMS_OUTPUT.put_line('INSERT INTO MyTable VALUES(' || valu || ', ' || n || ');');
EXCEPTION 
    WHEN bad_integer THEN
        DBMS_OUTPUT.put_line('Bad input(' || valu || ') for percentage(must be integer)');
    
    WHEN NO_DATA_FOUND THEN
        DBMS_OUTPUT.put_line('No id: (' || valu || ')');
END task_4;

BEGIN
    task_4();
END;


--SELECT * FROM MyTable WHERE mytable.id = &id;
DROP PROCEDURE my_table_insert;
CREATE OR REPLACE PROCEDURE my_table_insert(val NUMBER) IS
BEGIN
    INSERT INTO MyTable(val) VALUES (val);
END my_table_insert;

DROP PROCEDURE my_table_update;
CREATE OR REPLACE PROCEDURE my_table_update(id NUMBER, val NUMBER) IS
BEGIN
    UPDATE MyTable SET mytable.val = val WHERE MyTable.id = id;
END my_table_update;

DROP PROCEDURE my_table_delete;
CREATE OR REPLACE PROCEDURE my_table_delete(id NUMBER) IS
BEGIN
    DELETE FROM MyTable WHERE MyTable.id = id;
END my_table_delete;

BEGIN
    my_table_insert(0);
    my_table_update(10001, -1);
    my_table_delete(10001);
END;

DROP FUNCTION calculate_annual_remuneration;
CREATE OR REPLACE FUNCTION calculate_annual_remuneration(salary DECIMAL, percentage NUMBER) RETURN NUMBER IS
    total NUMBER;
BEGIN
    total := (1 + (percentage / 100.0)) * 12 * salary;
    
    RETURN total;
END calculate_annual_remuneration;

DROP FUNCTION is_number;
CREATE OR REPLACE FUNCTION is_number(conv_string VARCHAR2) RETURN BOOLEAN IS
    new_num NUMBER;
BEGIN
    new_num := TO_NUMBER(conv_string);
    RETURN TRUE;
EXCEPTION
    WHEN VALUE_ERROR THEN
        RETURN FALSE;
END is_number;

DROP FUNCTION is_integer;
CREATE OR REPLACE FUNCTION is_integer (conv_string IN VARCHAR2) RETURN BOOLEAN IS
BEGIN
    RETURN MOD(TO_NUMBER(conv_string), 1) = 0;
EXCEPTION
    WHEN VALUE_ERROR THEN
        RETURN FALSE;
END is_integer;

DROP PROCEDURE task_6;
CREATE OR REPLACE PROCEDURE task_6 IS
    salary VARCHAR2(30);
    percentage VARCHAR2(3);
    bad_number EXCEPTION;
    bad_integer EXCEPTION;
BEGIN
    salary := '&salary';
    percentage := '&percentage';
    IF NOT is_number(salary) OR TO_NUMBER(salary) < 0 THEN
        RAISE bad_number;
    END IF;
    
    IF NOT is_integer(percentage) OR TO_NUMBER(percentage) < 0 THEN
        RAISE bad_integer;
    END IF;  
    
    DBMS_OUTPUT.put_line('Annual remuneration: ' || calculate_annual_remuneration(TO_NUMBER(salary), TO_NUMBER(percentage)));
EXCEPTION
    WHEN bad_number THEN
        DBMS_OUTPUT.put_line('Bad input(' || salary || ') for salary');
    WHEN bad_integer THEN
        DBMS_OUTPUT.put_line('Bad input(' || percentage || ') for percentage(must be integer)');
END task_6;

BEGIN
    task_6();
END;