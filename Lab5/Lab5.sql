DROP TABLE product_order; /
DROP TABLE Orders; /
DROP TABLE Customers; /
DROP TABLE Products; /
DROP TABLE Customers_logs; /
DROP TABLE Products_logs; /
DROP TABLE Orders_logs; /
DROP TABLE product_order_logs; /

CREATE TABLE Customers
(
    id NUMBER GENERATED ALWAYS as IDENTITY PRIMARY KEY,
    name VARCHAR2(100) NOT NULL,
    surname VARCHAR2(100) NOT NULL
); /

CREATE TABLE Products
(
    id NUMBER GENERATED ALWAYS as IDENTITY PRIMARY KEY,
    name VARCHAR2(100) NOT NULL,
    price NUMBER(10, 2) NOT NULL
); /

CREATE TABLE Orders
(
    id NUMBER GENERATED ALWAYS as IDENTITY PRIMARY KEY,
    date_of_purchase TIMESTAMP NOT NULL,
    customer_id NUMBER NOT NULL,
    CONSTRAINT fk_customer_id FOREIGN KEY(customer_id)
    REFERENCES Customers(id)
); /

CREATE TABLE product_order
(
    id NUMBER GENERATED ALWAYS as IDENTITY PRIMARY KEY,
    product_id NUMBER NOT NULL,
    order_id NUMBER NOT NULL,
    quantity NUMBER DEFAULT 1,
    CONSTRAINT fk_product_id FOREIGN KEY(product_id)
    REFERENCES Products(id),
    CONSTRAINT fk_order_id FOREIGN KEY(order_id)
    REFERENCES Orders(id)
);


------------------------
--LOGS TABLES
CREATE TABLE Customers_logs
(
    id NUMBER GENERATED ALWAYS as IDENTITY PRIMARY KEY,
    change_time TIMESTAMP NOT NULL,
    operation_type VARCHAR2(1),
    display NUMBER(1) DEFAULT 1,
    customer_id NUMBER NOT NULL,
    old_name VARCHAR2(100),
    old_surname VARCHAR2(100),
    new_name VARCHAR2(100),
    new_surname VARCHAR2(100)
); /

CREATE TABLE Products_logs
(
    id NUMBER GENERATED ALWAYS as IDENTITY PRIMARY KEY,
    change_time TIMESTAMP NOT NULL,
    operation_type VARCHAR2(1),
    display NUMBER(1) DEFAULT 1,
    product_id NUMBER NOT NULL,
    old_name VARCHAR2(100),
    old_price NUMBER(10, 2),
    new_name VARCHAR2(100),
    new_price NUMBER(10, 2)
); /

CREATE TABLE Orders_logs
(
    id NUMBER GENERATED ALWAYS as IDENTITY PRIMARY KEY,
    change_time TIMESTAMP NOT NULL,
    operation_type VARCHAR2(1),
    display NUMBER(1) DEFAULT 1,
    order_id NUMBER NOT NULL,
    old_date_of_purchase TIMESTAMP,
    old_customer_id NUMBER,
    new_date_of_purchase TIMESTAMP,
    new_customer_id NUMBER
); /

CREATE TABLE product_order_logs
(
    id NUMBER GENERATED ALWAYS as IDENTITY PRIMARY KEY,
    change_time TIMESTAMP NOT NULL,
    operation_type VARCHAR2(1),
    display NUMBER(1) DEFAULT 1,
    product_order_id NUMBER NOT NULL,
    old_product_id NUMBER,
    old_order_id NUMBER,
    old_quantity NUMBER,
    new_product_id NUMBER,
    new_order_id NUMBER,
    new_quantity NUMBER
);

CREATE OR REPLACE TRIGGER log_customers_changes
AFTER INSERT OR UPDATE OR DELETE
ON Customers
FOR EACH ROW
DECLARE
    op_type varchar2(1) :=
        CASE WHEN UPDATING THEN 'U'
             WHEN DELETING THEN 'D'
             ELSE 'I' END;
BEGIN
    IF INSERTING THEN
        INSERT INTO Customers_logs VALUES
        (DEFAULT, SYSTIMESTAMP, op_type, DEFAULT, :NEW.id, NULL, NULL, :NEW.name, :NEW.surname);       
    ELSIF UPDATING THEN
        INSERT INTO Customers_logs VALUES
        (DEFAULT, SYSTIMESTAMP, op_type, DEFAULT, :OLD.id, :OLD.name, :OLD.surname, :NEW.name, :NEW.surname);
    ELSE
        INSERT INTO Customers_logs VALUES
        (DEFAULT, SYSTIMESTAMP, op_type, DEFAULT, :OLD.id, :OLD.name, :OLD.surname, NULL, NULL);    
    END IF;
END log_customers_changes;


CREATE OR REPLACE TRIGGER log_products_changes
AFTER INSERT OR UPDATE OR DELETE
ON Products
FOR EACH ROW
DECLARE
    op_type varchar2(1) :=
        CASE WHEN UPDATING THEN 'U'
             WHEN DELETING THEN 'D'
             ELSE 'I' END;
BEGIN
    IF INSERTING THEN
        INSERT INTO Products_logs VALUES
        (DEFAULT, SYSTIMESTAMP, op_type, DEFAULT, :NEW.id, NULL, NULL, :NEW.name, :NEW.price);       
    ELSIF UPDATING THEN
        INSERT INTO Products_logs VALUES
        (DEFAULT, SYSTIMESTAMP, op_type, DEFAULT, :OLD.id, :OLD.name, :OLD.price, :NEW.name, :NEW.price);
    ELSE
        INSERT INTO Products_logs VALUES
        (DEFAULT, SYSTIMESTAMP, op_type, DEFAULT, :OLD.id, :OLD.name, :OLD.price, NULL, NULL);    
    END IF;
END log_products_changes;


CREATE OR REPLACE TRIGGER log_orders_changes
AFTER INSERT OR UPDATE OR DELETE
ON Orders
FOR EACH ROW
DECLARE
    op_type varchar2(1) :=
        CASE WHEN UPDATING THEN 'U'
             WHEN DELETING THEN 'D'
             ELSE 'I' END;
BEGIN
    IF INSERTING THEN
        INSERT INTO Orders_logs VALUES
        (DEFAULT, SYSTIMESTAMP, op_type, DEFAULT, :NEW.id, NULL, NULL, 
                                                    :NEW.date_of_purchase, :NEW.customer_id);       
    ELSIF UPDATING THEN
        INSERT INTO Orders_logs VALUES
        (DEFAULT, SYSTIMESTAMP, op_type, DEFAULT, :OLD.id, :OLD.date_of_purchase, :OLD.customer_id, 
                                                :NEW.date_of_purchase, :NEW.customer_id);
    ELSE
        INSERT INTO Orders_logs VALUES
        (DEFAULT, SYSTIMESTAMP, op_type, DEFAULT, :OLD.id, :OLD.date_of_purchase, :OLD.customer_id, 
                                                NULL, NULL);    
    END IF;
END log_orders_changes;


CREATE OR REPLACE TRIGGER log_product_order_changes
AFTER INSERT OR UPDATE OR DELETE
ON product_order
FOR EACH ROW
DECLARE
    op_type varchar2(1) :=
        CASE WHEN UPDATING THEN 'U'
             WHEN DELETING THEN 'D'
             ELSE 'I' END;
BEGIN
    IF INSERTING THEN
        INSERT INTO product_order_logs VALUES
        (DEFAULT, SYSTIMESTAMP, op_type, DEFAULT, :NEW.id, NULL, NULL, NULL, 
                                        :NEW.product_id, :NEW.order_id, :NEW.quantity);       
    ELSIF UPDATING THEN
        INSERT INTO product_order_logs VALUES
        (DEFAULT, SYSTIMESTAMP, op_type, DEFAULT, :OLD.id, :OLD.product_id, :OLD.order_id, :OLD.quantity,
                                                    :NEW.product_id, :NEW.order_id, :NEW.quantity);
    ELSE
        INSERT INTO product_order_logs VALUES
        (DEFAULT, SYSTIMESTAMP, op_type, DEFAULT, :OLD.id, :OLD.product_id, :OLD.order_id, :OLD.quantity, 
                                                NULL, NULL, NULL);    
    END IF;
END log_product_order_changes;

DROP PROCEDURE restore_customers;
CREATE OR REPLACE PROCEDURE restore_customers(time_to_restore TIMESTAMP)
IS
    CURSOR logs IS
        SELECT * FROM Customers_logs
        WHERE change_time >= time_to_restore
        ORDER BY id DESC;
    new_id NUMBER;
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE Customers DISABLE ALL TRIGGERS';
    EXECUTE IMMEDIATE 'ALTER TABLE Customers MODIFY id GENERATED BY DEFAULT AS IDENTITY';
    FOR rec IN logs
    LOOP
        UPDATE Customers_logs SET display = 0 WHERE id = rec.id;
        IF rec.operation_type = 'U' THEN
            UPDATE Customers
            SET name = rec.old_name,
                surname = rec.old_surname
            WHERE id = rec.customer_id;
        ELSIF rec.operation_type = 'D' THEN
            new_id := rec.customer_id;
            INSERT INTO Customers(id, name, surname)
            VALUES (rec.customer_id, rec.old_name, rec.old_surname);
        ELSE
            DELETE FROM Customers WHERE id = rec.customer_id;
        END IF;
    END LOOP;
    SELECT NVL(MAX(ID), 0) + 1 INTO new_id FROM Customers;
    EXECUTE IMMEDIATE 'ALTER TABLE Customers MODIFY id GENERATED ALWAYS AS IDENTITY(START WITH ' 
        || new_id || ' INCREMENT BY 1)';
    EXECUTE IMMEDIATE 'ALTER TABLE Customers ENABLE ALL TRIGGERS';
END restore_customers;


DROP PROCEDURE restore_products;
CREATE OR REPLACE PROCEDURE restore_products(time_to_restore TIMESTAMP)
IS
    CURSOR logs IS
        SELECT * FROM Products_logs
        WHERE change_time >= time_to_restore
        ORDER BY id DESC;
    new_id NUMBER;
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE Products DISABLE ALL TRIGGERS';
    EXECUTE IMMEDIATE 'ALTER TABLE Products MODIFY id GENERATED BY DEFAULT AS IDENTITY';
    FOR rec IN logs
    LOOP
        UPDATE Products_logs SET display = 0 WHERE id = rec.id;
        IF rec.operation_type = 'U' THEN
            UPDATE Products
            SET name = rec.old_name,
                price = rec.old_price
            WHERE id = rec.product_id;
        ELSIF rec.operation_type = 'D' THEN
            INSERT INTO Products(id, name, price)
            VALUES (rec.product_id, rec.old_name, rec.old_price);
        ELSE
            DELETE FROM Products WHERE id = rec.product_id;
        END IF;
    END LOOP;
    SELECT NVL(MAX(ID), 0) + 1 INTO new_id FROM Products;
    EXECUTE IMMEDIATE 'ALTER TABLE Products MODIFY id GENERATED ALWAYS AS IDENTITY START WITH ' 
        || new_id || ' INCREMENT BY 1';
    EXECUTE IMMEDIATE 'ALTER TABLE Products ENABLE ALL TRIGGERS';
END restore_products;


DROP PROCEDURE restore_orders;
CREATE OR REPLACE PROCEDURE restore_orders(time_to_restore TIMESTAMP)
IS
    CURSOR logs IS
        SELECT * FROM Orders_logs
        WHERE change_time >= time_to_restore
        ORDER BY id DESC;
    new_id NUMBER;
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE Orders DISABLE ALL TRIGGERS';
    EXECUTE IMMEDIATE 'ALTER TABLE Orders MODIFY id GENERATED BY DEFAULT AS IDENTITY';
    FOR rec IN logs
    LOOP
        UPDATE Orders_logs SET display = 0 WHERE id = rec.id;
        IF rec.operation_type = 'U' THEN
            UPDATE Orders
            SET date_of_purchase = rec.old_date_of_purchase,
                customer_id = rec.old_customer_id
            WHERE id = rec.order_id;
        ELSIF rec.operation_type = 'D' THEN
            INSERT INTO Orders(id, date_of_purchase, customer_id)
            VALUES (rec.order_id, rec.old_date_of_purchase, rec.old_customer_id);
        ELSE
            DELETE FROM Orders WHERE id = rec.order_id;
        END IF;
    END LOOP;
    SELECT NVL(MAX(ID), 0) + 1 INTO new_id FROM Orders;
    EXECUTE IMMEDIATE 'ALTER TABLE Orders MODIFY id GENERATED ALWAYS AS IDENTITY START WITH ' 
        || new_id || ' INCREMENT BY 1';
    EXECUTE IMMEDIATE 'ALTER TABLE Orders ENABLE ALL TRIGGERS';
END restore_orders;


DROP PROCEDURE restore_product_order;
CREATE OR REPLACE PROCEDURE restore_product_order(time_to_restore TIMESTAMP)
IS
    CURSOR logs IS
        SELECT * FROM product_order_logs
        WHERE change_time >= time_to_restore
        ORDER BY id DESC;
    new_id NUMBER;
BEGIN
    EXECUTE IMMEDIATE 'ALTER TABLE product_order DISABLE ALL TRIGGERS';
    EXECUTE IMMEDIATE 'ALTER TABLE product_order MODIFY id GENERATED BY DEFAULT AS IDENTITY';
    FOR rec IN logs
    LOOP
        UPDATE product_order_logs SET display = 0 WHERE id = rec.id;
        IF rec.operation_type = 'U' THEN
            UPDATE product_order
            SET product_id = rec.old_product_id,
                order_id = rec.old_order_id,
                quantity = rec.old_quantity
            WHERE id = rec.product_order_id;
        ELSIF rec.operation_type = 'D' THEN
            INSERT INTO product_order(id, product_id, order_id, quantity)
            VALUES (rec.product_order_id, rec.old_product_id, rec.old_order_id, rec.old_quantity);
        ELSE
            DELETE FROM product_order WHERE id = rec.product_order_id;
        END IF;
    END LOOP;
    SELECT NVL(MAX(ID), 0) + 1 INTO new_id FROM product_order;
    EXECUTE IMMEDIATE 'ALTER TABLE product_order MODIFY id GENERATED ALWAYS AS IDENTITY START WITH ' 
        || new_id || ' INCREMENT BY 1';
    EXECUTE IMMEDIATE 'ALTER TABLE product_order ENABLE ALL TRIGGERS';
END restore_product_order;


CREATE OR REPLACE PACKAGE restoration
IS
    PROCEDURE restore_data(time_to_restore TIMESTAMP);
    PROCEDURE restore_data(interval_millisecs NUMBER);
END restoration;


CREATE OR REPLACE PACKAGE BODY restoration
IS
    PROCEDURE restore_data(time_to_restore TIMESTAMP)
    IS
    BEGIN
        restore_customers(time_to_restore);
        restore_products(time_to_restore);
        restore_orders(time_to_restore);
        restore_product_order(time_to_restore);
    END restore_data;
    
    
    PROCEDURE restore_data(interval_millisecs NUMBER)
    IS
    BEGIN
        restore_data(SYSTIMESTAMP  - (INTERVAL '0.001' SECOND) * interval_millisecs);
    END restore_data;
END restoration;


CREATE OR REPLACE FUNCTION log_stat(log_tab_name VARCHAR2) RETURN VARCHAR2
IS
    TYPE arr IS VARRAY(3) 
        OF VARCHAR2(1) NOT NULL;
     types_arr arr := arr('I', 'U', 'D');
    i_num NUMBER;
    res_str VARCHAR2(500);
BEGIN
    res_str := HTF.TABLEOPEN || CHR(10) || HTF.TABLEROWOPEN 
        || CHR(10) || HTF.TABLEHEADER(log_tab_name) 
        || CHR(10) || HTF.TABLEROWCLOSE || CHR(10);
    FOR ind IN types_arr.FIRST..types_arr.LAST
    LOOP
        EXECUTE IMMEDIATE 'SELECT COUNT(*) FROM ' || log_tab_name 
            ||' WHERE display = 1 AND operation_type = ' || CHR(39) || types_arr(ind) || CHR(39) INTO i_num;
        res_str := res_str || HTF.TABLEROWOPEN
            || CHR(10) || HTF.TABLEDATA(types_arr(ind)) 
            || CHR(10) || HTF.TABLEDATA(i_num) 
            || CHR(10) || HTF.TABLEROWCLOSE || CHR(10);
    END LOOP;
    res_str := res_str || CHR(10) || HTF.TABLECLOSE;
    RETURN res_str;
END log_stat;


CREATE OR REPLACE DIRECTORY DIR_TO_WRITE AS 'D:\Study\Third_Grade\6_sem\DB\LR\Lab5';
CREATE OR REPLACE PROCEDURE create_report
IS
    w_file   UTL_FILE.file_type;
    res_str VARCHAR2(500);
    TYPE arr IS VARRAY(4) 
        OF VARCHAR2(30) NOT NULL;
    types_arr arr := arr('Customers_logs', 'Products_logs', 'Orders_logs', 'product_order_logs');
BEGIN
    w_file := UTL_FILE.fopen('DIR_TO_WRITE', 'report.html', 'W');
    res_str := HTF.HTMLOPEN || CHR(10) || HTF.headopen || CHR(10) || HTF.title('Lab stat') 
            || CHR(10) || HTF.headclose || CHR(10) ||HTF.bodyopen || CHR(10);
    UTL_FILE.put_line (w_file, res_str); 
    FOR ind IN types_arr.FIRST..types_arr.LAST
    LOOP
        UTL_FILE.put_line (w_file, CHR(10) || log_stat(types_arr(ind)));
    END LOOP;
    res_str := CHR(10) || HTF.bodyclose || CHR(10) || HTF.htmlclose;
    UTL_FILE.put_line(w_file, res_str);
    UTL_FILE.fclose(w_file);
END create_report;

BEGIN
    restoration.restore_data(TO_TIMESTAMP('02-APR-23 07.56.46.491000000 PM','DD-MON-RR HH12.MI.SS.FF AM'));
    create_report;
END;

--TO_TIMESTAMP('02-APR-23 07.23.12.098000000 PM','DD-MON-RR HH12.MI.SS.FF AM')