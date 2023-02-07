

DROP TABLE Groups;
CREATE TABLE Groups 
(
    id NUMBER GENERATED ALWAYS as IDENTITY(START with 1 INCREMENT by 1) NOT NULL PRIMARY KEY,
    name VARCHAR2(200) NOT NULL,
    c_val NUMBER DEFAULT 0
);

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


CREATE OR REPLACE TRIGGER num_students_update
AFTER DELETE OR INSERT
ON Students
FOR EACH ROW
BEGIN
    UPDATE Groups 
    SET c_val = (SELECT COUNT(*) FROM Students WHERE group_id = OLD.id)
    WHERE id = OLD.id;
END num_students_update;