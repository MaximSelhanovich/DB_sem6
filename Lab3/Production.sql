DROP TABLE MyTable; /
DROP TABLE NEWTABLE; / 
DROP TABLE table_not_in_dev; /
DROP INDEX my_tab_index_for_test;
CREATE INDEX my_tab_index_for_test ON MyTable(name, val);

DROP INDEX my_tab_index_NOT_IN_DEV;
CREATE INDEX my_tab_index_NOT_IN_DEV ON MyTable(times);

DROP TABLE MyTable; /
CREATE TABLE MyTable 
(
    id NUMBER GENERATED ALWAYS as IDENTITY(START with 1 INCREMENT by 1) NOT NULL PRIMARY KEY,
    val NUMBER,
    name varchar2(200),
    constraint uinGt_id check (VAL between 0 and 4294967295),
    constraint uint_id check (id between 54 and 4294967295)
);

CREATE TABLE NEWTABLE
(
    id NUMBER GENERATED ALWAYS as IDENTITY(START with 1 INCREMENT by 1) not null PRIMARY KEY,
    STUDENT_ID NUMBER NOT NULL
);

CREATE TABLE table_not_in_dev
(
    id NUMBER GENERATED ALWAYS as IDENTITY(START with 1 INCREMENT by 1) not null PRIMARY KEY,
    STUDENT_ID NUMBER NOT NULL
);

CREATE OR REPLACE PROCEDURE test_name(PAR1 VARCHAR2, PAR2 NUMBER)
IS
    N BOOLEAN;
BEGIN
    N := TRUE;
    
END test_name;

CREATE OR REPLACE PROCEDURE test_name_PROD(PAR1 VARCHAR2, PAR2 NUMBER)
IS
    N BOOLEAN;
BEGIN

    N := TRUE;
END test_name_PROD;

CREATE OR REPLACE FUNCTION fffftest_name(PAR1 VARCHAR2, PAR2 NUMBER) RETURN BOOLEAN
IS
    N BOOLEAN;
BEGIN
    N := TRUE;
    
END fffftest_name;

CREATE OR REPLACE PACKAGE test_dev_package_IN_PROD AS
    test_dev_package_var NUMBER := 0;
    PROCEDURE test_dev_package_PROCEDURE;
    tttttt_t NUMBER := test_dev_package_var + 1;
    PROCEDURE test_name_PROD(PAR1 VARCHAR2, PAR2 NUMBER);
END test_dev_package_IN_PROD;


CREATE OR REPLACE PACKAGE test_dev_package AS
    test_dev_package_var NUMBER := 0;
    PROCEDURE test_dev_package_PROCEDURE;
    PROCEDURE test_name_PROD(PAR1 VARCHAR2, PAR2 NUMBER);
END test_dev_package; 

CREATE OR REPLACE PACKAGE BODY test_dev_package AS
        PROCEDURE test_name_PROD(PAR1 VARCHAR2, PAR2 NUMBER)
    IS
        N BOOLEAN;
    BEGIN
        N := TRUE;
    END test_name_PROD;
    
    
    PROCEDURE test_dev_package_PROCEDURE 
    IS
        N BOOLEAN;
    BEGIN
        N := TRUE;
    END test_dev_package_PROCEDURE;
    
        PROCEDURE ASD 
    IS
        N BOOLEAN;
    BEGIN
        N := TRUE;
    END ASD;
END test_dev_package;


SELECT * FROM USER_IDENTIFIERS WHERE type in ('PACKAGE BODY', 'PACKAGE');


DROP PACKAGE test_dev_package_not_in_dev;
CREATE OR REPLACE PACKAGE test_dev_package_not_in_dev as
PROCEDURE test_name_PROD(PAR1 VARCHAR2, PAR2 NUMBER);
END test_dev_package_not_in_dev;

DROP PACKAGE BODY test_dev_package_not_in_dev;
CREATE OR REPLACE PACKAGE BODY test_dev_package_not_in_dev  as
        PROCEDURE test_name_PROD(PAR1 VARCHAR2, PAR2 NUMBER)
    IS
        N BOOLEAN;
    BEGIN
        N := TRUE;
    END test_name_PROD;
end test_dev_package_not_in_dev;

DROP PACKAGE tpackage;
CREATE OR REPLACE PACKAGE tpackage AS
    test_dev_package_var NUMBER := 0;
END tpackage;
