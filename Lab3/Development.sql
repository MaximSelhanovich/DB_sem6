DROP TABLE MyTable; /
DROP TABLE Students; /
DROP TABLE Groups; /
DROP TABLE NEWTABLE; /
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
    id number
); /

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
);
SELECT
  COUNT(*)
FROM
  all_tables;