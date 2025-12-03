# Shell DBMS - SQL Command Reference

Complete reference for all SQL-like commands supported in this shell-based Database Management System.

---

## Table of Contents

1. [Database Operations](#database-operations)
2. [Table Operations](#table-operations)
3. [Data Manipulation](#data-manipulation)
4. [Data Query](#data-query)
5. [Operators Reference](#operators-reference)
6. [Workflow Example](#Complete-Workflow-Example)

---

## Database Operations

### CREATE DATABASE

Creates a new database.

**Syntax:**
```sql
CREATE DATABASE <database_name>
```

**Rules:**
- Database name must start with a letter
- Only alphanumeric characters and underscores allowed
- Database name cannot be empty

**Example:**
```sql
CREATE DATABASE Company
CREATE DATABASE employee_db
```

---

### DROP DATABASE

Deletes an existing database.

**Syntax:**
```sql
DROP DATABASE <database_name>
```

**Example:**
```sql
DROP DATABASE old_database
```

---

### LIST DATABASES

Lists all available databases.

**Syntax:**
```sql
LIST DATABASES
```

**Example:**
```sql
LIST DATABASES
```

---

### USE

Connects to a specific database for operations.

**Syntax:**
```sql
USE <database_name>
```

**Example:**
```sql
USE Company
```

---

## Table Operations

### CREATE TABLE

Creates a new table with specified columns.

**Syntax (Non-Interactive):**
```sql
CREATE TABLE <table_name> COLUMNS (col1:type:pk, col2:type, ...)
```

**Column Definition Format:**
- `column_name:data_type[:PK]`
- Comma-separated list
- Enclosed in parentheses
- `PK` suffix marks primary key (optional, case-insensitive)

**Supported Data Types:**
- `int` - Integer values
- `string` - Text values

**Rules:**
- Table name must start with a letter
- Only alphanumeric characters and underscores allowed
- At most one primary key per table
- Column names must be unique within a table

**Examples:**
```sql
CREATE TABLE employees COLUMNS (id:int:PK, name:string, age:int, salary:int)

CREATE TABLE products COLUMNS (product_id:int:pk, name:string, price:int)

CREATE TABLE customers COLUMNS (SSID:int:PK, Position:string, Salary:int, Department:string)
```

**Interactive Mode:**
```sql
CREATE TABLE <table_name>
```
(System will prompt for column details)

---

### DROP TABLE

Deletes an existing table.

**Syntax:**
```sql
DROP TABLE <table_name>
```

**Example:**
```sql
DROP TABLE old_employees
```

---

### LIST TABLES

Lists all tables in the current database.

**Syntax:**
```sql
LIST TABLES
```

**Example:**
```sql
USE Company
LIST TABLES
```

---

### TRUNCATE TABLE

Removes all rows from a table while keeping the structure.

**Syntax:**
```sql
TRUNCATE TABLE <table_name>
```

**Example:**
```sql
TRUNCATE TABLE employees
```

---

## Data Manipulation

### INSERT INTO

Inserts a new row into a table.

**Syntax:**
```sql
INSERT INTO <table_name> VALUES (value1, value2, ...)
```

**Rules:**
- Number of values must match number of columns
- String values can be enclosed in single quotes
- Primary key cannot be NULL
- Primary key must be unique
- Integer columns must receive valid integer values

**Examples:**
```sql
INSERT INTO employees VALUES (1, 'Alice', 30, 5000)

INSERT INTO employees VALUES (2, 'Bob', 25, 4000)

INSERT INTO products VALUES (101, 'Laptop', 1200)
```

---

### UPDATE

Updates existing rows based on a condition.

**Syntax:**
```sql
UPDATE <table_name> SET <assignments> WHERE <condition>
```

**Assignment Format:**
- Single: `column=value`
- Multiple: `col1=value1, col2=value2, col3=value3`
- Comma-separated
- Values can be quoted with single quotes

**Condition Format:**
```
<column> <operator> <value>
```

**Supported Operators:**
- `=` or `==` - Equals
- `!=` - Not equals
- `>` - Greater than
- `<` - Less than
- `>=` - Greater than or equal
- `<=` - Less than or equal
- `LIKE` - Pattern matching (use `%` for wildcard, `_` for single char)

**Examples:**

Single column update:
```sql
UPDATE employees SET name='Alice Updated' WHERE id = 1
```

Multiple column update:
```sql
UPDATE employees SET age=26, salary=4200 WHERE id = 2
```

String condition:
```sql
UPDATE employees SET salary=6500 WHERE name = 'Charlie'
```

Numeric comparison:
```sql
UPDATE employees SET salary=8000 WHERE age > 35

UPDATE employees SET salary=3000 WHERE age < 27
```

LIKE pattern:
```sql
UPDATE employees SET name='David Updated' WHERE name LIKE 'Dav%'

UPDATE employees SET status='Active' WHERE email LIKE '%@company.com'
```

---

### DELETE FROM

Deletes rows from a table based on a condition.

**Syntax:**
```sql
DELETE FROM <table_name> WHERE <condition>
```

**Condition Format:**
```
<column> <operator> <value>
```

**Supported Operators:** (same as UPDATE)
- `=`, `==`, `!=`, `>`, `<`, `>=`, `<=`, `LIKE`

**Examples:**

Delete by exact match:
```sql
DELETE FROM employees WHERE id = 1
```

Delete by string condition:
```sql
DELETE FROM employees WHERE name = 'Bob'
```

Delete by numeric comparison:
```sql
DELETE FROM employees WHERE age > 60

DELETE FROM products WHERE price < 10
```

Delete by pattern:
```sql
DELETE FROM employees WHERE name LIKE 'Temp%'
```

---

## Data Query

### SELECT ALL FROM

Retrieves all rows and columns from a table.

**Syntax:**
```sql
SELECT ALL FROM <table_name>
```

**Example:**
```sql
SELECT ALL FROM employees

SELECT ALL FROM products
```

---

### SELECT Specific Columns

Retrieves specific columns from all rows.

**Syntax:**
```sql
SELECT <column1>,<column2>,... FROM <table_name>
```

**Rules:**
- Column names are comma-separated
- No spaces around commas (or use consistently)

**Examples:**
```sql
SELECT name,age FROM employees

SELECT id,name FROM employees

SELECT product_id,name,price FROM products
```

---

### SELECT with WHERE (Primary Key)

Retrieves rows matching a primary key value.

**Syntax:**
```sql
SELECT ALL FROM <table_name> WHERE <pk_column> = <value>
```

**Example:**
```sql
SELECT ALL FROM employees WHERE id = 1

SELECT ALL FROM products WHERE product_id = 101
```

---

## Operators Reference

### Comparison Operators

| Operator | Description | Example |
|----------|-------------|---------|
| `=` or `==` | Equals | `WHERE id = 5` |
| `!=` | Not equals | `WHERE status != 'inactive'` |
| `>` | Greater than | `WHERE age > 30` |
| `<` | Less than | `WHERE salary < 5000` |
| `>=` | Greater or equal | `WHERE age >= 18` |
| `<=` | Less or equal | `WHERE price <= 100` |
| `LIKE` | Pattern match | `WHERE name LIKE 'A%'` |

### LIKE Pattern Wildcards

| Wildcard | Description | Example | Matches |
|----------|-------------|---------|---------|
| `%` | Zero or more characters | `'A%'` | Alice, Andrew, A |
| `_` | Exactly one character | `'A_'` | AB, A1, Ax |

**LIKE Examples:**
```sql
-- Names starting with 'A'
WHERE name LIKE 'A%'

-- Names ending with 'son'
WHERE name LIKE '%son'

-- Names containing 'art'
WHERE name LIKE '%art%'

-- Exactly 3 characters
WHERE code LIKE '___'

-- Starts with 'A' and has exactly 3 chars
WHERE name LIKE 'A__'
```

---

## General Commands

### EXIT / QUIT

Exits the query interface.

**Syntax:**
```sql
EXIT
QUIT
```

### BACK

Exits from a database session back to the main DBMS prompt.

**Syntax:**
```sql
BACK
```

---

# Complete Workflow Example

This comprehensive example demonstrates a complete database lifecycle with multiple tables and all supported operations.

```sql
-- ============================================
-- PART 1: Database Setup
-- ============================================

-- Create a new database
CREATE DATABASE Company

-- List all databases to verify creation
LIST DATABASES

-- Connect to the database
USE Company

-- ============================================
-- PART 2: Create Tables
-- ============================================

-- Create employees table
CREATE TABLE employees COLUMNS (id:int:PK, name:string, age:int, salary:int, department:string)

-- Create departments table
CREATE TABLE departments COLUMNS (dept_id:int:PK, dept_name:string, budget:int)

-- Create projects table
CREATE TABLE projects COLUMNS (project_id:int:PK, project_name:string, employee_id:int, status:string)

-- List all tables
LIST TABLES

-- ============================================
-- PART 3: Insert Data
-- ============================================

-- Insert employees
INSERT INTO employees VALUES (1, 'Alice Johnson', 30, 5000, 'Engineering')
INSERT INTO employees VALUES (2, 'Bob Smith', 25, 4000, 'Marketing')
INSERT INTO employees VALUES (3, 'Charlie Brown', 35, 6000, 'Engineering')
INSERT INTO employees VALUES (4, 'Diana Prince', 28, 5500, 'Sales')
INSERT INTO employees VALUES (5, 'Eve Davis', 40, 7000, 'Engineering')
INSERT INTO employees VALUES (6, 'Frank Miller', 32, 4500, 'Marketing')
INSERT INTO employees VALUES (7, 'Grace Lee', 27, 4800, 'Sales')

-- Insert departments
INSERT INTO departments VALUES (1, 'Engineering', 50000)
INSERT INTO departments VALUES (2, 'Marketing', 30000)
INSERT INTO departments VALUES (3, 'Sales', 40000)

-- Insert projects
INSERT INTO projects VALUES (101, 'Website Redesign', 1, 'Active')
INSERT INTO projects VALUES (102, 'Mobile App', 3, 'Active')
INSERT INTO projects VALUES (103, 'Marketing Campaign', 2, 'Completed')
INSERT INTO projects VALUES (104, 'Sales Dashboard', 4, 'Active')

-- ============================================
-- PART 4: Query Data (SELECT)
-- ============================================

-- Select all employees
SELECT ALL FROM employees

-- Select specific columns
SELECT name,salary FROM employees
SELECT name,age,department FROM employees

-- Select with WHERE condition (exact match)
SELECT ALL FROM employees WHERE id = 1
SELECT ALL FROM employees WHERE department = 'Engineering'

-- ============================================
-- PART 5: Update Data
-- ============================================

-- Single column update with exact match
UPDATE employees SET salary=5500 WHERE id = 1

-- Multiple column update
UPDATE employees SET age=26, salary=4200 WHERE name = 'Bob Smith'

-- Update based on numeric comparison
UPDATE employees SET salary=8000 WHERE age > 35
UPDATE employees SET salary=3000 WHERE salary < 4500

-- Update based on string pattern (LIKE)
UPDATE employees SET department='Senior Engineering' WHERE name LIKE 'Alice%'
UPDATE projects SET status='Completed' WHERE project_name LIKE '%Campaign%'

-- Update multiple rows
UPDATE employees SET salary=6000 WHERE department = 'Engineering'

-- Verify updates
SELECT ALL FROM employees
SELECT ALL FROM projects

-- ============================================
-- PART 6: Delete Data
-- ============================================

-- Delete by exact match
DELETE FROM employees WHERE id = 7

-- Delete by string condition
DELETE FROM projects WHERE status = 'Completed'

-- Delete by numeric comparison
DELETE FROM employees WHERE age > 60
DELETE FROM employees WHERE salary < 3500

-- Delete by pattern
DELETE FROM employees WHERE name LIKE 'Temp%'

-- Verify deletions
SELECT ALL FROM employees
SELECT ALL FROM projects

-- ============================================
-- PART 7: More Complex Operations
-- ============================================

-- Add more test data
INSERT INTO employees VALUES (8, 'Henry Ford', 45, 9000, 'Engineering')
INSERT INTO employees VALUES (9, 'Iris West', 29, 5200, 'Sales')

-- Update with greater than or equal
UPDATE employees SET salary=10000 WHERE age >= 40

-- Update with less than or equal
UPDATE departments SET budget=35000 WHERE budget <= 40000

-- Delete with not equal
DELETE FROM employees WHERE department != 'Engineering'

-- Verify final state
SELECT ALL FROM employees
SELECT ALL FROM departments

-- ============================================
-- PART 8: Table Management
-- ============================================

-- Create a temporary table for testing
CREATE TABLE temp_data COLUMNS (id:int:PK, value:string)

-- Insert test data
INSERT INTO temp_data VALUES (1, 'test1')
INSERT INTO temp_data VALUES (2, 'test2')

-- View the data
SELECT ALL FROM temp_data

-- Truncate table (removes all rows, keeps structure)
TRUNCATE TABLE temp_data

-- Verify table is empty
SELECT ALL FROM temp_data

-- Drop the temporary table
DROP TABLE temp_data

-- List remaining tables
LIST TABLES

-- ============================================
-- PART 9: Cleanup
-- ============================================

-- Drop all tables
DROP TABLE projects
DROP TABLE employees
DROP TABLE departments

-- Verify all tables are gone
LIST TABLES

-- Exit from database
BACK

-- Drop the database
DROP DATABASE Company

-- List databases to verify deletion
LIST DATABASES

-- Exit the DBMS
EXIT
```

### Workflow Summary

This example demonstrates:
1. **Database lifecycle**: CREATE, USE, DROP
2. **Table operations**: CREATE with schema, LIST, TRUNCATE, DROP
3. **Data insertion**: Multiple INSERT statements with various data types
4. **Querying**: SELECT ALL, SELECT columns, SELECT with WHERE
5. **Updates**: Single/multiple columns, various operators (=, >, <, >=, <=, LIKE)
6. **Deletions**: DELETE with various conditions and operators
7. **Pattern matching**: LIKE with wildcards (%)
8. **Complete cleanup**: Removing all created objects

---

## Notes

- All commands are **case-insensitive** for keywords (CREATE, SELECT, WHERE, etc.)
- Table and column names are **case-sensitive**
- String values can be enclosed in **single quotes** `'value'`
- Numeric values should **not** be quoted
- Primary key values cannot be NULL or duplicated
- The `WHERE` clause is **required** for UPDATE and DELETE operations
- Operations are performed within the context of the currently connected database (via `USE`)

---

*End of SQL Reference*
