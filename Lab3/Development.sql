DROP TABLE MyChildTable; /
DROP TABLE MyTable; /
ALTER TABLE Students DROP CONSTRAINT fk_group_id; /
ALTER TABLE GROUPS DROP CONSTRAINT fk_new_table_id; /
ALTER TABLE NEWTABLE DROP CONSTRAINT fk_STUDENT_id; /
DROP TABLE Students; /
DROP TABLE Groups; /
DROP TABLE NEWTABLE; /

CREATE TABLE MyChildTable
(
    id NUMBER GENERATED ALWAYS as IDENTITY(START with 1 INCREMENT by 1) NOT NULL PRIMARY KEY,
    MyTable_id number not null,
    CONSTRAINT fk_mytable_id
        FOREIGN KEY (MyTable_id)
        REFERENCES Groups(id)
); /


CREATE TABLE MyTable 
(
    id NUMBER GENERATED ALWAYS as IDENTITY(START with 1 INCREMENT by 1) NOT NULL PRIMARY KEY,
    val NUMBER,
    name varchar2(200),
    times TIMESTAMP,
    constraint uint_id check (id between 0 and 4294967295)
); /

CREATE TABLE NEWTABLE
(
    id NUMBER GENERATED ALWAYS as IDENTITY(START with 1 INCREMENT by 1) not null PRIMARY KEY,
    STUDENT_ID NUMBER NOT NULL
); /

CREATE TABLE Groups 
(
    id NUMBER GENERATED ALWAYS as IDENTITY(START with 1 INCREMENT by 1) NOT NULL PRIMARY KEY,
    name VARCHAR2(200) NOT NULL,
    c_val NUMBER DEFAULT 0,
    new_table_id number not null  
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

ALTER TABLE groups add CONSTRAINT fk_new_table_id
        FOREIGN KEY (new_table_id)
        REFERENCES NEWTABLE(id); /
        
ALTER TABLE NEWTABLE add CONSTRAINT fk_STUDENT_id
        FOREIGN KEY (STUDENT_ID)
        REFERENCES sTUDENTS(id); 

SELECT * FROM all_constraints WHERE OWNER ='C##DEVELOPMENT';