DROP TABLE MyTable; /
CREATE TABLE MyTable 
(
    id NUMBER GENERATED ALWAYS as IDENTITY(START with 1 INCREMENT by 1) NOT NULL PRIMARY KEY,
    val NUMBER,
    constraint uint_id check (id between 0 and 4294967295)
);