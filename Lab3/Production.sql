DROP TABLE MyTable; /
CREATE TABLE MyTable 
(
    id NUMBER GENERATED ALWAYS as IDENTITY(START with 1 INCREMENT by 1) NOT NULL PRIMARY KEY,
    val NUMBER,
    constraint uint_id check (id between 0 and 4294967295)
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


CREATE OR REPLACE PACKAGE test_dev_package AS
    test_dev_package_var NUMBER := 0;
    PROCEDURE test_dev_package_PROCEDURE;
    PROCEDURE test_name_PROD(PAR1 VARCHAR2, PAR2 NUMBER);
END test_dev_package; /

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
END test_dev_package;
