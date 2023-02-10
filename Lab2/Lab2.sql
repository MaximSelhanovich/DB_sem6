DROP TABLE Students; /
DROP TABLE Groups; /

CREATE TABLE Groups 
(
    id NUMBER GENERATED ALWAYS as IDENTITY(START with 1 INCREMENT by 1) NOT NULL PRIMARY KEY,
    name VARCHAR2(200) NOT NULL,
    c_val NUMBER DEFAULT 0
); /

CREATE TABLE Students
(
    id NUMBER GENERATED ALWAYS as IDENTITY(START with 1 INCREMENT by 1) NOT NULL PRIMARY KEY,
    name VARCHAR2(200) NOT NULL,
    group_id NUMBER NOT NULL,
    CONSTRAINT fk_group_id
        FOREIGN KEY (group_id)
        REFERENCES Groups(id)
); /

DROP TRIGGER cascade_students_delete;
CREATE OR REPLACE TRIGGER cascade_students_delete
BEFORE DELETE 
ON Groups
FOR EACH ROW
BEGIN
    DELETE FROM students WHERE students.group_id = :OLD.id;
END cascade_students_delete;

DROP TRIGGER num_students_update; / 
CREATE OR REPLACE TRIGGER num_students_update
BEFORE DELETE OR INSERT
ON Students
FOR EACH ROW
DECLARE
    PRAGMA AUTONOMOUS_TRANSACTION;
    n number;
BEGIN
    CASE
        WHEN INSERTING THEN
            dbms_output.put_line('Befor update: (' || :NEW.group_id || ')');
            SELECT c_val INTO n FROM groups WHERE groups.id = :NEW.group_id;
            dbms_output.put_line('Check existanxe: (' || n || ')');
            UPDATE Groups SET groups.c_val = groups.c_val + 1 
            WHERE groups.id = :NEW.group_id;
            --COMMIT;
            dbms_output.put_line('After update groups: (' || :NEW.group_id || ')');
            --COMMIT;
        WHEN DELETING THEN
            UPDATE Groups SET groups.c_val = groups.c_val - 1
            WHERE groups.id = :OLD.group_id;
            dbms_output.put_line('MINUS ONE: (' || :OLD.group_id ||')');
            --COMMIT;
        END CASE;
    COMMIT;
exception
    when no_data_found then
        dbms_output.put_line(SQLERRM);
END num_students_update; /
BEGIN
    dbms_output.put_line('Finish');
END; /

insert into Groups(name) values('yes'); /
insert into Groups(name) values('NO'); /
insert into Groups(name) values('Maybe'); /
commit;
select * from Groups;

insert into students(name, group_id) values('Mario', 2); /
insert into students(name, group_id) values('sONIC', 2); /
insert into students(name, group_id) values('Duck', 3); /
commit;

SELECT * FROM groups; /
DELETE FROM students WHERE students.NAME = 'sONIC';


DELETE FROM groups WHERE NAME = 'NO'; /
SELECT * FROM STUDENTS;