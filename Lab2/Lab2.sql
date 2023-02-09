DROP TABLE Groups;
CREATE TABLE Groups 
(
    id NUMBER GENERATED ALWAYS as IDENTITY(START with 1 INCREMENT by 1) NOT NULL PRIMARY KEY,
    name VARCHAR2(200) NOT NULL,
    c_val NUMBER DEFAULT 0
);
insert into Groups(name) values('yes');
select * from Groups;

DROP TABLE Students;
CREATE TABLE Students 
(
    id NUMBER GENERATED ALWAYS as IDENTITY(START with 1 INCREMENT by 1) NOT NULL PRIMARY KEY,
    name VARCHAR2(200) NOT NULL,
    group_id NUMBER NOT NULL,
    CONSTRAINT fk_group_id
        FOREIGN KEY (group_id)
        REFERENCES Groups(id)
);
insert into students(name, group_id) values('Mario', 1);
insert into students(name, group_id) values('sONIC', 1);
SELECT * FROM students;
DELETE FROM students WHERE students.NAME = 'sONIC';

DROP TRIGGER num_students_update;

CREATE OR REPLACE TRIGGER num_students_update
AFTER DELETE OR INSERT
ON Students 
FOR EACH ROW
BEGIN
    CASE
        WHEN INSERTING THEN 
            UPDATE Groups SET groups.c_val = groups.c_val + 1 
            WHERE groups.id = :NEW.group_id;
        WHEN DELETING THEN
            UPDATE Groups SET groups.c_val = groups.c_val - 1
            WHERE groups.id = :OLD.group_id;
        END CASE;
END num_students_update;