/********************************************************/
/* Prep */
/********************************************************/
SET SQL_MODE=ORACLE;

/* Update the delimiter to execute with / instead of ; */
DELIMITER /

/* Create a new schema */
CREATE DATABASE onboarding /

USE onboarding /

CREATE TABLE employees (
    id INT(11) unsigned NOT NULL AUTO_INCREMENT,
    first_name VARCHAR2(200) NOT NULL,
    last_name VARCHAR2(200) NOT NULL,
    department CHAR(3) NOT NULL,
    position_level INT(1) NOT NULL,
    PRIMARY KEY (id)
);

CREATE TABLE tasks (
    id INT(11) unsigned NOT NULL AUTO_INCREMENT,
    emp_id INT(11) unsigned NOT NULL,
    `description` VARCHAR2(200) NOT NULL,
    completed BOOLEAN NOT NULL DEFAULT 0,  
    PRIMARY KEY (id),
    CONSTRAINT `fk_emp` FOREIGN KEY (emp_id) REFERENCES employees (id) ON DELETE CASCADE ON UPDATE CASCADE
); /

/* See how the Oracle data types have been converted to MariaDB synonyms */
SHOW COLUMNS FROM tasks /

/********************************************************/
/* Procedure Sample */
/********************************************************/
CREATE OR REPLACE PROCEDURE add_employee(fname IN VARCHAR2, lname IN VARCHAR2, dept IN VARCHAR2, pos_level IN INTEGER) AS
BEGIN
    IF ((fname <> '') && (lname <> '') && (dept <> '') && (pos_level > 0)) THEN
        INSERT INTO employees (first_name,last_name,department,position_level)
        VALUES (fname,lname,dept,pos_level);
    ELSE
        SELECT 'Insufficient information provided' AS WARNING;
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        SELECT 'Exception ' || SQLCODE || ' ' || SQLERRM AS EXCEPTION;
END;
/

/********************************************************/
/* Test it out! */
/********************************************************/
CALL add_employee('Kate', 'Austin', 'ENG', 3);
CALL add_employee('Jack', 'Shephard', 'MKT', 2);

SELECT * FROM employees /

/********************************************************/
/* Package Sample */
/********************************************************/
CREATE OR REPLACE PACKAGE task_helper AS
    PROCEDURE add_task(emp_id tasks.emp_id%TYPE, description tasks.description%TYPE);
    PROCEDURE complete_task(id tasks.id%TYPE);
    FUNCTION incomplete_task_count(emp_id tasks.emp_id%TYPE) RETURN VARCHAR;
END;

CREATE OR REPLACE PACKAGE BODY task_helper AS 

    PROCEDURE add_task(emp_id tasks.emp_id%TYPE, description tasks.description%TYPE) AS
    BEGIN
        INSERT INTO tasks (emp_id, description) VALUES (emp_id, description);
    END;

    PROCEDURE complete_task(id tasks.id%TYPE) AS
    BEGIN
        UPDATE tasks t SET t.completed = 1 WHERE t.id = id;
    END;

    FUNCTION incomplete_task_count(emp_id tasks.emp_id%TYPE) RETURN VARCHAR AS 
        cnt INTEGER;
        INVALID_ID EXCEPTION;
    BEGIN 
        IF emp_id > 0 THEN
            SELECT COUNT(*) INTO cnt 
            FROM tasks t 
            WHERE t.emp_id = emp_id AND t.completed = 0;
            RETURN cnt;
        ELSE 
            RAISE INVALID_ID;
        END IF;
    EXCEPTION
        WHEN INVALID_ID THEN
            RETURN 'An invalid id was provided.';
        WHEN OTHERS THEN
            RETURN 'An error has occurred.';  
    END;
END; /

/********************************************************/
/* Test it out! */
/********************************************************/
BEGIN
    task_helper.add_task(1, 'New Task 1-1');
END;

CALL task_helper.add_task(1, 'New Task 1-2');
CALL task_helper.add_task(2, 'New Task 2-2'); /

CALL task_helper.complete_task(3); /

SELECT id, first_name, last_name, task_helper.incomplete_task_count(id) AS incompleted_tasks FROM employees; /
SELECT task_helper.incomplete_task_count(-1); /

/********************************************************/
/* Trigger Sample */
/********************************************************/
CREATE OR REPLACE TRIGGER add_employee_trg after insert ON employees FOR EACH ROW
BEGIN
    DECLARE
        id employees.id%TYPE := :NEW.id;
        dept employees.department%TYPE := :NEW.department;
        pos_level employees.position_level%TYPE := :NEW.position_level;
    BEGIN
        IF (dept = 'ENG') THEN
            FOR i IN 1..pos_level LOOP
                task_helper.add_task(id,'Review Pull Request');
            END LOOP;
        ELSIF (dept = 'MKT') THEN
            task_helper.add_task(id,'New Marketing Employee Task');
        END IF;
        task_helper.add_task(id,'New Employee Task');
    END;
END;
/

/********************************************************/
/* Test it out! */
/********************************************************/
CALL add_employee('Ben', 'Linus', 'MKT', 2);
CALL add_employee('John', 'Locke', 'ENG', 3);

SELECT e.first_name, e.last_name, t.description 
FROM employees e 
    INNER JOIN tasks t ON e.id = t.emp_id; /
 
