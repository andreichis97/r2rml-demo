# R2RML Demo — PostgreSQL + Ontop Virtual Knowledge Graph

This project demonstrates how **R2RML mappings** can be used to expose data stored in a relational PostgreSQL database as an RDF knowledge graph without physically copying the relational data into a graph database.

The demo uses:

* **PostgreSQL** as the relational data source
* **R2RML** as the relational-to-RDF mapping language
* **Ontop** as the Virtual Knowledge Graph (VKG) / OBDA engine
* **SPARQL** for querying the semantic view of the data
* **Docker Compose** for running the complete environment

The main goal is to understand how a traditional relational schema can be mapped to a semantic model and queried through SPARQL while the original data remains stored in PostgreSQL.

---

## 1. Architecture

The demo implements the following architecture:

```text
                     SPARQL Query
                          |
                          v
                 +----------------+
                 |     Ontop      |
                 |                |
                 | Virtual RDF KG |
                 +-------+--------+
                         |
                         | R2RML mappings
                         |
                         | SPARQL -> SQL
                         v
                 +----------------+
                 |   PostgreSQL   |
                 |                |
                 | customer       |
                 | orders         |
                 +----------------+
```

Ontop does **not** create a second database containing RDF triples.

Instead, the RDF graph is virtual:

```text
SPARQL
   |
   v
Ontop
   |
   | consults R2RML mappings
   v
SQL
   |
   v
PostgreSQL
   |
   v
Query results
   |
   v
RDF / SPARQL bindings
```

The relational database therefore remains the authoritative source of data.

---

# 2. What the Demo Shows

The project demonstrates four fundamental mapping scenarios:

### Relational table → RDF class

```text
customer
    |
    v
ex:Customer
```

### Relational column → RDF datatype property

```text
customer.name
    |
    v
ex:name
```

### Primary key → RDF resource identifier

```text
customer.id = 1
    |
    v
http://example.org/customer/1
```

### SQL relationship → RDF object property

```text
customer.id = orders.customer_id
    |
    v
ex:Customer -- ex:placedOrder --> ex:Order
```

Together, these mappings create a semantic abstraction over the underlying relational database.

---

# 3. Project Structure

The project is organized as follows:

```text
r2rml-demo/
|
├── docker-compose.yml
|
├── database/
│   └── init.sql
|
├── ontop/
│   ├── database.properties
│   ├── mapping.ttl
│   └── ontology.ttl
|
├── jdbc/
│   └── postgresql-<version>.jar
|
├── queries/
│   ├── customers.rq
│   └── customer-orders.rq
|
└── output/
```

The directories have the following roles:

| Path        | Purpose                                              |
| ----------- | ---------------------------------------------------- |
| `database/` | PostgreSQL schema and initial test data              |
| `ontop/`    | Ontology, R2RML mapping and DB configuration         |
| `jdbc/`     | PostgreSQL JDBC driver used by Ontop                 |
| `queries/`  | Example SPARQL queries                               |
| `output/`   | Optional directory for generated/materialized output |

---

# 4. Prerequisites

The only essential runtime prerequisite is Docker.

Verify the installation using:

```bash
docker --version
docker compose version
```

The example was developed using Docker Desktop on macOS, but it should also work with Docker on Linux and Windows.

---

# 5. Relational Data Model

The PostgreSQL database contains two tables:

```text
+------------------+
| customer         |
+------------------+
| id PK            |
| name             |
| email            |
+--------+---------+
         |
         | 1
         |
         | N
+--------v---------+
| orders           |
+------------------+
| id PK            |
| customer_id FK   |
| amount           |
+------------------+
```

A customer can therefore have multiple orders.

---

# 6. PostgreSQL Initialization

Create:

```text
database/init.sql
```

with the following content:

```sql
CREATE TABLE customer (
    id INTEGER PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL
);

CREATE TABLE orders (
    id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    amount DECIMAL(10,2) NOT NULL,

    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES customer(id)
);

INSERT INTO customer (id, name, email)
VALUES
    (1, 'Alice Smith', 'alice@example.com'),
    (2, 'Bob Jones', 'bob@example.com'),
    (3, 'Carol White', 'carol@example.com');

INSERT INTO orders (id, customer_id, amount)
VALUES
    (101, 1, 250.00),
    (102, 1, 120.00),
    (103, 2, 500.00),
    (104, 3, 75.50),
    (105, 3, 300.00);
```

This produces the following customer data:

```text
id | name        | email
---+-------------+-------------------
1  | Alice Smith | alice@example.com
2  | Bob Jones   | bob@example.com
3  | Carol White | carol@example.com
```

and the following orders:

```text
id  | customer_id | amount
----+-------------+--------
101 | 1           | 250.00
102 | 1           | 120.00
103 | 2           | 500.00
104 | 3           | 75.50
105 | 3           | 300.00
```

---

# 7. Semantic Model

The semantic model deliberately abstracts away the physical database structure.

Conceptually, it consists of:

```text
+------------------+
| Customer         |
+------------------+
| name             |
| email            |
+--------+---------+
         |
         | placedOrder
         v
+------------------+
| Order            |
+------------------+
| amount           |
+------------------+
```

The semantic vocabulary contains:

### Classes

```text
ex:Customer
ex:Order
```

### Datatype properties

```text
ex:name
ex:email
ex:amount
```

### Object properties

```text
ex:placedOrder
ex:customer
```

---

# 8. Ontology

Create:

```text
ontop/ontology.ttl
```

with:

```turtle
@prefix ex:   <http://example.org/> .
@prefix owl:  <http://www.w3.org/2002/07/owl#> .
@prefix rdf:  <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
@prefix rdfs: <http://www.w3.org/2000/01/rdf-schema#> .
@prefix xsd:  <http://www.w3.org/2001/XMLSchema#> .


# Classes

ex:Customer
    a owl:Class .

ex:Order
    a owl:Class .


# Datatype properties

ex:name
    a owl:DatatypeProperty ;
    rdfs:domain ex:Customer ;
    rdfs:range xsd:string .

ex:email
    a owl:DatatypeProperty ;
    rdfs:domain ex:Customer ;
    rdfs:range xsd:string .

ex:amount
    a owl:DatatypeProperty ;
    rdfs:domain ex:Order ;
    rdfs:range xsd:decimal .


# Object properties

ex:placedOrder
    a owl:ObjectProperty ;
    rdfs:domain ex:Customer ;
    rdfs:range ex:Order .

ex:customer
    a owl:ObjectProperty ;
    rdfs:domain ex:Order ;
    rdfs:range ex:Customer ;
    owl:inverseOf ex:placedOrder .
```

The ontology represents the **semantic layer**.

It does not need to contain implementation-specific concepts such as:

```text
customer_id
VARCHAR
DECIMAL
SQL foreign key
```

Those details belong to the physical data layer and mapping layer.

---

# 9. R2RML Mapping

Create:

```text
ontop/mapping.ttl
```

with:

```turtle
@prefix rr:  <http://www.w3.org/ns/r2rml#> .
@prefix ex:  <http://example.org/> .
@prefix xsd: <http://www.w3.org/2001/XMLSchema#> .


#################################################################
# Customer mapping
#################################################################

<#CustomerMap>
    a rr:TriplesMap ;

    rr:logicalTable [
        rr:tableName "customer"
    ] ;

    rr:subjectMap [
        rr:template "http://example.org/customer/{id}" ;
        rr:class ex:Customer ;
        rr:termType rr:IRI
    ] ;

    # customer.name -> ex:name

    rr:predicateObjectMap [
        rr:predicate ex:name ;

        rr:objectMap [
            rr:column "name"
        ]
    ] ;

    # customer.email -> ex:email

    rr:predicateObjectMap [
        rr:predicate ex:email ;

        rr:objectMap [
            rr:column "email"
        ]
    ] ;

    # Customer -> Order relationship

    rr:predicateObjectMap [
        rr:predicate ex:placedOrder ;

        rr:objectMap [
            rr:parentTriplesMap <#OrderMap> ;

            rr:joinCondition [
                rr:child "id" ;
                rr:parent "customer_id"
            ]
        ]
    ] .


#################################################################
# Order mapping
#################################################################

<#OrderMap>
    a rr:TriplesMap ;

    rr:logicalTable [
        rr:tableName "orders"
    ] ;

    rr:subjectMap [
        rr:template "http://example.org/order/{id}" ;
        rr:class ex:Order ;
        rr:termType rr:IRI
    ] ;

    # orders.amount -> ex:amount

    rr:predicateObjectMap [
        rr:predicate ex:amount ;

        rr:objectMap [
            rr:column "amount" ;
            rr:datatype xsd:decimal
        ]
    ] ;

    # Order -> Customer relationship

    rr:predicateObjectMap [
        rr:predicate ex:customer ;

        rr:objectMap [
            rr:parentTriplesMap <#CustomerMap> ;

            rr:joinCondition [
                rr:child "customer_id" ;
                rr:parent "id"
            ]
        ]
    ] .
```

---

# 10. Understanding the R2RML Mapping

R2RML mappings are RDF graphs themselves.

The main construct is:

```text
rr:TriplesMap
```

A Triples Map describes how rows obtained from a relational logical table are transformed into RDF triples.

A simplified structure is:

```text
TriplesMap
    |
    +-- Logical Table
    |
    +-- Subject Map
    |
    +-- Predicate-Object Map
    |
    +-- Predicate-Object Map
    |
    ...
```

---

## 10.1 Logical Table

For example:

```turtle
rr:logicalTable [
    rr:tableName "customer"
]
```

tells the R2RML processor that this mapping operates over the `customer` table.

Conceptually:

```text
customer rows
      |
      v
CustomerMap
```

---

## 10.2 Subject Map

The following mapping:

```turtle
rr:subjectMap [
    rr:template "http://example.org/customer/{id}" ;
    rr:class ex:Customer ;
    rr:termType rr:IRI
]
```

takes the relational primary key and creates an RDF resource identifier.

For:

```text
id = 1
```

the generated RDF identifier is:

```text
http://example.org/customer/1
```

The mapping also declares the resource as:

```turtle
<http://example.org/customer/1>
    a ex:Customer .
```

---

## 10.3 Datatype Property Mapping

The following mapping:

```turtle
rr:predicateObjectMap [
    rr:predicate ex:name ;

    rr:objectMap [
        rr:column "name"
    ]
]
```

connects:

```text
customer.name
```

to:

```text
ex:name
```

For the SQL value:

```text
Alice Smith
```

the virtual RDF graph contains:

```turtle
<http://example.org/customer/1>
    ex:name "Alice Smith" .
```

---

## 10.4 Mapping Relationships

One of the most important parts of the example is the relationship mapping.

The relational database represents the relationship through:

```text
orders.customer_id
```

which references:

```text
customer.id
```

R2RML can expose this SQL relationship as an RDF object property.

Conceptually:

```text
SQL

customer.id = orders.customer_id

              |
              v

RDF

Customer -- ex:placedOrder --> Order
```

For example:

```text
customer.id = 1

orders:
101 -> customer 1
102 -> customer 1
```

becomes conceptually:

```turtle
<http://example.org/customer/1>
    ex:placedOrder
        <http://example.org/order/101> ,
        <http://example.org/order/102> .
```

The relational foreign-key structure is therefore exposed as a graph relationship.

---

# 11. Ontop Database Configuration

Create:

```text
ontop/database.properties
```

with:

```properties
jdbc.url=jdbc:postgresql://db:5432/toydb
jdbc.user=postgres
jdbc.password=postgres
jdbc.driver=org.postgresql.Driver
```

The hostname is intentionally:

```text
db
```

and not:

```text
localhost
```

because Ontop and PostgreSQL execute in separate Docker containers.

Docker Compose provides internal DNS resolution using service names:

```text
Ontop container
      |
      | JDBC
      v
db:5432
      |
      v
PostgreSQL container
```

From the host machine, PostgreSQL is available through `localhost`.

From the Ontop container, PostgreSQL is available through `db`.

---

# 12. PostgreSQL JDBC Driver

Ontop requires the PostgreSQL JDBC driver.

Download a compatible PostgreSQL JDBC `.jar` file and place it under:

```text
jdbc/
```

For example:

```text
jdbc/
└── postgresql-42.7.x.jar
```

The complete JDBC directory is mounted into the Ontop container at:

```text
/opt/ontop/jdbc
```

There is normally no need to reference the JAR filename explicitly from the Ontop configuration.

---

# 13. Docker Compose

Create:

```text
docker-compose.yml
```

with:

```yaml
services:

  db:
    image: postgres:17-alpine
    container_name: r2rml-postgres

    environment:
      POSTGRES_DB: toydb
      POSTGRES_USER: postgres
      POSTGRES_PASSWORD: postgres

    ports:
      - "5432:5432"

    volumes:
      - postgres_data:/var/lib/postgresql/data
      - ./database/init.sql:/docker-entrypoint-initdb.d/init.sql:ro

    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres -d toydb"]
      interval: 5s
      timeout: 5s
      retries: 10


  ontop:
    image: ontop/ontop:5.5.0
    container_name: r2rml-ontop

    depends_on:
      db:
        condition: service_healthy

    environment:
      ONTOP_MAPPING_FILE: /opt/ontop/input/mapping.ttl
      ONTOP_ONTOLOGY_FILE: /opt/ontop/input/ontology.ttl
      ONTOP_PROPERTIES_FILE: /opt/ontop/input/database.properties

      ONTOP_CORS_ALLOWED_ORIGINS: "*"
      ONTOP_DEV_MODE: "true"
      ONTOP_LAZY_INIT: "true"

    volumes:
      - ./ontop:/opt/ontop/input:ro
      - ./jdbc:/opt/ontop/jdbc:ro

    ports:
      - "8080:8080"


volumes:
  postgres_data:
```

`ONTOP_LAZY_INIT` is useful during development because it allows Ontop to initialize lazily while the environment is starting.

`ONTOP_DEV_MODE` is useful while developing and modifying mappings.

---

# 14. Starting the Environment

From the project root:

```bash
docker compose pull
```

Then start the services:

```bash
docker compose up -d
```

Check their status:

```bash
docker compose ps
```

Both containers should be running:

```text
r2rml-postgres
r2rml-ontop
```

PostgreSQL should eventually report a healthy status.

---

# 15. Inspecting Logs

PostgreSQL logs:

```bash
docker compose logs db
```

Ontop logs:

```bash
docker compose logs ontop
```

Follow Ontop logs continuously:

```bash
docker compose logs -f ontop
```

This is particularly useful when debugging:

* invalid R2RML syntax
* missing JDBC drivers
* database connection problems
* invalid table or column names
* SPARQL reformulation problems

---

# 16. Verify PostgreSQL

Connect directly to PostgreSQL:

```bash
docker exec -it r2rml-postgres psql -U postgres -d toydb
```

The prompt should become:

```text
toydb=#
```

---

## List Customers

Run:

```sql
SELECT * FROM customer;
```

Expected result:

```text
 id |    name     |       email
----+-------------+-------------------
  1 | Alice Smith | alice@example.com
  2 | Bob Jones   | bob@example.com
  3 | Carol White | carol@example.com
```

---

## List Orders

```sql
SELECT * FROM orders;
```

Expected result:

```text
 id  | customer_id | amount
-----+-------------+--------
 101 |           1 | 250.00
 102 |           1 | 120.00
 103 |           2 | 500.00
 104 |           3 |  75.50
 105 |           3 | 300.00
```

---

## Test the Relational Join

```sql
SELECT
    c.name,
    o.id AS order_id,
    o.amount
FROM customer c
JOIN orders o
    ON c.id = o.customer_id;
```

Expected logical result:

```text
Alice Smith | 101 | 250.00
Alice Smith | 102 | 120.00
Bob Jones   | 103 | 500.00
Carol White | 104 | 75.50
Carol White | 105 | 300.00
```

This SQL join is important because the R2RML mapping later exposes the same relationship as:

```text
Customer -- placedOrder --> Order
```

---

## Useful `psql` Commands

SQL statements must end in a semicolon:

```sql
SELECT * FROM customer;
```

If the prompt changes from:

```text
toydb=#
```

to:

```text
toydb-#
```

PostgreSQL is waiting for the current SQL statement to be completed.

To reset an unfinished command:

```text
\r
```

To exit PostgreSQL:

```text
\q
```

---

# 17. Accessing Ontop

Once Ontop is running, open its web interface on port:

```text
8080
```

Ontop includes a browser-based SPARQL interface.

The actual SPARQL endpoint is available under:

```text
/sparql
```

The following experiments can then be executed.

---

# 18. Experiment 1 — Retrieve RDF Customers

Run:

```sparql
PREFIX ex: <http://example.org/>

SELECT ?customer
WHERE {
    ?customer a ex:Customer .
}
```

Expected resources:

```text
http://example.org/customer/1
http://example.org/customer/2
http://example.org/customer/3
```

This demonstrates the mapping:

```text
customer table
      |
      v
ex:Customer
```

PostgreSQL itself knows nothing about `ex:Customer`.

The class exists only at the semantic layer.

---

# 19. Experiment 2 — Retrieve Customer Attributes

Run:

```sparql
PREFIX ex: <http://example.org/>

SELECT ?customer ?name ?email
WHERE {
    ?customer a ex:Customer ;
              ex:name ?name ;
              ex:email ?email .
}
ORDER BY ?customer
```

Conceptually:

```text
SPARQL                    PostgreSQL

ex:Customer        ->     customer
ex:name            ->     customer.name
ex:email           ->     customer.email
```

Expected results include:

```text
customer/1 | Alice Smith | alice@example.com
customer/2 | Bob Jones   | bob@example.com
customer/3 | Carol White | carol@example.com
```

---

# 20. Experiment 3 — Query Customers and Their Orders

Run:

```sparql
PREFIX ex: <http://example.org/>

SELECT ?customer ?name ?order ?amount
WHERE {
    ?customer a ex:Customer ;
              ex:name ?name ;
              ex:placedOrder ?order .

    ?order ex:amount ?amount .
}
ORDER BY ?customer ?order
```

Expected logical result:

```text
Alice Smith | order/101 | 250.00
Alice Smith | order/102 | 120.00
Bob Jones   | order/103 | 500.00
Carol White | order/104 | 75.50
Carol White | order/105 | 300.00
```

This experiment demonstrates an important capability.

SPARQL contains:

```sparql
?customer ex:placedOrder ?order .
```

but the SQL database contains no column or table called:

```text
placedOrder
```

Instead, the relationship exists relationally as:

```text
customer.id = orders.customer_id
```

The R2RML mapping provides the semantic interpretation:

```text
customer.id
      =
orders.customer_id

        |
        v

ex:placedOrder
```

---

# 21. Experiment 4 — Aggregation Through SPARQL

The semantic layer can also be queried using SPARQL aggregation.

Find customers whose total order value exceeds 300:

```sparql
PREFIX ex: <http://example.org/>

SELECT ?customer ?name (SUM(?amount) AS ?totalAmount)
WHERE {
    ?customer a ex:Customer ;
              ex:name ?name ;
              ex:placedOrder ?order .

    ?order ex:amount ?amount .
}
GROUP BY ?customer ?name
HAVING (SUM(?amount) > 300)
ORDER BY DESC(?totalAmount)
```

Before modifying the dataset, the expected totals are:

```text
Bob Jones    | 500.00
Carol White  | 375.50
Alice Smith  | 370.00
```

Ontop translates the semantic SPARQL query into SQL operations executed by PostgreSQL.

---

# 22. Experiment 5 — Demonstrating That the Graph Is Virtual

One of the most important experiments is modifying PostgreSQL directly and observing the result immediately through SPARQL.

Connect to PostgreSQL:

```bash
docker exec -it r2rml-postgres psql -U postgres -d toydb
```

Add another order:

```sql
INSERT INTO orders (id, customer_id, amount)
VALUES (106, 1, 999.99);
```

Exit:

```text
\q
```

Do **not** restart Ontop.

Run:

```sparql
PREFIX ex: <http://example.org/>

SELECT ?order ?amount
WHERE {
    <http://example.org/customer/1>
        ex:placedOrder ?order .

    ?order ex:amount ?amount .
}
ORDER BY ?order
```

The result should now contain:

```text
order/101 | 250.00
order/102 | 120.00
order/106 | 999.99
```

This demonstrates that Ontop is exposing a **Virtual Knowledge Graph**.

There was no process such as:

```text
PostgreSQL
    |
    v
Export RDF
    |
    v
Import RDF
    |
    v
Graph database
```

Instead:

```text
SPARQL request
      |
      v
Ontop
      |
      | R2RML mappings
      v
Generated SQL
      |
      v
PostgreSQL
      |
      v
Current database values
```

The RDF representation is generated virtually when queries are evaluated.

---

# 23. Experiment 6 — Semantic Model Can Change Without Changing the Database

Suppose the semantic model should use:

```text
ex:fullName
```

instead of:

```text
ex:name
```

The physical database can remain unchanged:

```text
customer.name
```

Only the mapping needs to change from:

```turtle
rr:predicate ex:name ;
```

to:

```turtle
rr:predicate ex:fullName ;
```

The ontology should be updated accordingly.

The semantic query then becomes:

```sparql
PREFIX ex: <http://example.org/>

SELECT ?customer ?name
WHERE {
    ?customer ex:fullName ?name .
}
```

This illustrates the abstraction provided by the mapping layer:

```text
PHYSICAL DATA MODEL

customer.name

       |
       | R2RML mapping
       v

SEMANTIC MODEL

ex:fullName
```

The operational database schema does not need to be modified merely because the semantic vocabulary changes.

---

# 24. SPARQL Query Files

For convenience, example queries can be stored under:

```text
queries/
```

For example:

```text
queries/customers.rq
```

```sparql
PREFIX ex: <http://example.org/>

SELECT ?customer ?name ?email
WHERE {
    ?customer a ex:Customer ;
              ex:name ?name ;
              ex:email ?email .
}
ORDER BY ?name
```

And:

```text
queries/customer-orders.rq
```

```sparql
PREFIX ex: <http://example.org/>

SELECT ?customer ?name ?order ?amount
WHERE {
    ?customer a ex:Customer ;
              ex:name ?name ;
              ex:placedOrder ?order .

    ?order a ex:Order ;
           ex:amount ?amount .
}
ORDER BY ?name ?order
```

---

# 25. How Ontop Processes a Query

Consider:

```sparql
PREFIX ex: <http://example.org/>

SELECT ?name ?amount
WHERE {
    ?customer ex:name ?name ;
              ex:placedOrder ?order .

    ?order ex:amount ?amount .
}
```

Ontop first interprets the semantic query.

It sees:

```text
ex:name
ex:placedOrder
ex:amount
```

It then consults the R2RML mappings.

Conceptually:

```text
ex:name
    |
    v
customer.name


ex:placedOrder
    |
    v
customer.id = orders.customer_id


ex:amount
    |
    v
orders.amount
```

The resulting SQL is conceptually similar to:

```sql
SELECT
    c.name,
    o.amount
FROM customer c
JOIN orders o
    ON c.id = o.customer_id;
```

The exact SQL generated by Ontop may be more complex because Ontop also handles:

* RDF term construction
* datatypes
* null handling
* query optimization
* SPARQL semantics

The important transformation is:

```text
SPARQL
    |
    v
Semantic concepts
    |
    v
R2RML mappings
    |
    v
SQL
    |
    v
Relational database
```

---

# 26. Inspecting Generated SQL

For additional visibility into Ontop's query processing, logging can be increased.

Add the following environment variable to the Ontop service if required:

```yaml
ONTOP_LOG_LEVEL: "DEBUG"
```

Then monitor:

```bash
docker compose logs -f ontop
```

Debug logging can help inspect the SQL generated from SPARQL queries.

This is particularly useful for understanding how:

```sparql
?customer ex:placedOrder ?order .
```

becomes a relational join.

---

# 27. Resetting the Environment

Stop the containers:

```bash
docker compose stop
```

Start them again:

```bash
docker compose start
```

Completely stop and remove the containers:

```bash
docker compose down
```

The PostgreSQL data remains stored in the Docker volume.

---

## Completely Reset PostgreSQL

To delete the database volume:

```bash
docker compose down -v
```

Then recreate everything:

```bash
docker compose up -d
```

The initialization script will execute again.

> **Warning:** `docker compose down -v` deletes the PostgreSQL volume and all data stored in it. This is appropriate for the toy environment but should not be used casually against production environments.

---

# 28. Important Docker Initialization Behavior

The file:

```text
database/init.sql
```

is executed by the PostgreSQL Docker image only when a new PostgreSQL data directory is initialized.

Therefore, changing:

```text
database/init.sql
```

after the PostgreSQL volume already exists will **not** automatically rebuild the database.

For this demo, recreate it using:

```bash
docker compose down -v
docker compose up -d
```

---

# 29. Troubleshooting

## PostgreSQL Query Does Not Execute

Inside `psql`, SQL commands must end with:

```text
;
```

Correct:

```sql
SELECT * FROM customer;
```

If the prompt becomes:

```text
toydb-#
```

instead of:

```text
toydb=#
```

PostgreSQL is waiting for the statement to be completed.

Reset the unfinished statement using:

```text
\r
```

---

## Ontop Cannot Connect to PostgreSQL

Check:

```properties
jdbc.url=jdbc:postgresql://db:5432/toydb
```

Inside Docker Compose, use:

```text
db
```

not:

```text
localhost
```

---

## PostgreSQL Port 5432 Is Already Used

If PostgreSQL is already running locally, change:

```yaml
ports:
  - "5432:5432"
```

to, for example:

```yaml
ports:
  - "5433:5432"
```

Do **not** change the Ontop JDBC URL.

Ontop should still use:

```properties
jdbc.url=jdbc:postgresql://db:5432/toydb
```

because communication between the containers uses the internal Docker network.

---

## PostgreSQL JDBC Driver Cannot Be Found

Verify that the driver exists:

```text
jdbc/
└── postgresql-*.jar
```

Then restart Ontop:

```bash
docker compose restart ontop
```

If necessary:

```bash
docker compose down
docker compose up -d
```

---

## Mapping Errors

Check:

```bash
docker compose logs ontop
```

Common problems include:

* Turtle syntax errors
* incorrect table names
* incorrect column names
* invalid R2RML constructs
* malformed prefixes
* missing JDBC driver

---

# 30. The Three-Layer Architecture

The most important conceptual takeaway from this demo is the separation between three layers.

## Physical Data Layer

Defined by PostgreSQL:

```text
customer
orders
customer.id
customer.name
customer.email
orders.customer_id
orders.amount
```

---

## Mapping Layer

Defined using R2RML:

```text
customer              -> ex:Customer
customer.name         -> ex:name
customer.email        -> ex:email
orders                -> ex:Order
orders.amount         -> ex:amount

customer.id
      =
orders.customer_id    -> ex:placedOrder
```

---

## Semantic Layer

Defined using RDF/OWL:

```text
Customer
Order

name
email
amount
placedOrder
customer
```

The complete architecture is therefore:

```text
              SEMANTIC MODEL

        Customer ----- placedOrder -----> Order
           |                                |
         name                             amount
         email

                       ^
                       |
                       |
                  R2RML MAPPINGS
                       |
                       |
                       v

               PHYSICAL MODEL

        customer ----------------------- orders
           id        1          N       customer_id
           name                         amount
           email
```

---

# 31. Why Use a Semantic Layer?

A conventional application could simply query:

```sql
SELECT ...
FROM customer
JOIN orders ...
```

For a single small database, introducing RDF and R2RML may therefore appear unnecessary.

The value becomes more apparent when the semantic model acts as an abstraction over multiple heterogeneous operational systems.

For example:

```text
                     SEMANTIC BACKBONE

                Organization
                Person
                Customer
                Order
                Project
                Invoice

                       ^
                       |
                    mappings
                       |
        +--------------+--------------+
        |              |              |
        v              v              v

    CRM system     ERP database    Project DB
```

Different systems may use completely different terminology and schemas.

For example:

```text
System                    Operational concept

CRM                       Account
Project Management        Client
Billing                   Debtor
```

All three may represent the same broader business concept:

```text
ex:Organization
```

The semantic layer provides the canonical meaning, while mappings connect source-specific representations to it.

---

# 32. Example of Semantic Integration

Suppose an enterprise has:

### PostgreSQL

```text
customer
orders
invoice
```

### Salesforce

```text
Account
Contact
Opportunity
```

### Project Management System

```text
Client
Project
Assignment
```

The semantic layer could define:

```text
Organization
Person
Customer
Order
Invoice
Opportunity
Project
Employee
```

Mappings could then establish relationships such as:

```text
PostgreSQL customer     -> Organization
Salesforce Account      -> Organization
PM Client               -> Organization

Salesforce Contact      -> Person

PostgreSQL orders       -> Order

Salesforce Opportunity  -> Opportunity

PM Project              -> Project
```

Applications could subsequently query the semantic layer rather than directly depending on each operational schema.

Conceptually:

```text
                         SPARQL

                            |
                            v

                 +---------------------+
                 | Semantic Backbone   |
                 |                     |
                 | Organization        |
                 | Person              |
                 | Project             |
                 | Order               |
                 | Opportunity         |
                 +----------+----------+
                            |
                         mappings
                            |
            +---------------+---------------+
            |               |               |
            v               v               v
       PostgreSQL       Salesforce      Project DB
```

---

# 33. Important Limitation: R2RML and Heterogeneous Sources

R2RML is specifically designed for mapping **relational databases to RDF**.

Therefore:

```text
PostgreSQL -> R2RML
MySQL      -> R2RML
SQL Server -> R2RML
Oracle     -> R2RML
```

are natural use cases.

A system exposed only through JSON, XML, CSV files or REST APIs requires a different mapping or integration mechanism.

A related technology is **RML**, which extends the general mapping approach to heterogeneous data sources.

Conceptually:

```text
R2RML
    |
    +-- relational databases


RML
    |
    +-- relational databases
    +-- CSV
    +-- JSON
    +-- XML
    +-- other logical sources
```

A real enterprise semantic integration architecture may therefore combine several types of adapters or mapping technologies.

---

# 34. Entity Identity Across Data Sources

Mapping schemas is only one part of semantic integration.

Consider the following records:

### PostgreSQL

```text
customer.id = 17
name = Acme SRL
vat_number = RO123456
```

### CRM

```text
Account.Id = ABC123
Name = ACME S.R.L.
VAT = RO123456
```

Both records represent the same real organization.

If each mapping creates unrelated identifiers:

```text
http://example.org/sql/customer/17

http://example.org/crm/account/ABC123
```

the semantic graph will initially contain two different resources.

A better strategy, when a stable enterprise identifier exists, is to generate a canonical identifier such as:

```text
http://example.org/organization/RO123456
```

Both systems can then map to the same semantic entity:

```text
PostgreSQL customer
          \
           \
            > organization/RO123456
           /
          /
CRM Account
```

This introduces an additional enterprise integration concern:

```text
Schema integration
        +
Entity resolution
        +
Query federation
```

R2RML mainly addresses the **schema-to-semantic mapping** component.

---

# 35. Virtual Knowledge Graph vs Materialized Knowledge Graph

This demo uses a Virtual Knowledge Graph.

## Virtual approach

```text
SPARQL
   |
   v
Ontop
   |
   v
SQL
   |
   v
PostgreSQL
```

Advantages include:

* data stays in the source system
* no RDF synchronization pipeline is required
* database updates can immediately become visible
* operational systems remain authoritative
* no duplicated graph storage is required

---

## Materialized approach

An alternative architecture would be:

```text
PostgreSQL
    |
    | mapping
    v
RDF triples
    |
    v
Graph database
```

In that case, RDF data is physically generated and loaded into a graph database.

Ontop can also materialize the virtual RDF graph if a physical RDF representation is required.

---

# 36. Key Takeaways

This demo illustrates several important concepts.

### R2RML does not replace the relational database

The existing database remains unchanged.

```text
PostgreSQL
```

continues to contain tables, primary keys and foreign keys.

---

### R2RML defines the bridge between physical and semantic models

For example:

```text
customer.name
      |
      v
ex:name
```

or:

```text
customer.id = orders.customer_id
      |
      v
ex:placedOrder
```

---

### Ontop executes the mapping

Ontop interprets:

```text
SPARQL
+
R2RML
+
Ontology
```

and translates semantic queries into SQL.

---

### RDF resources can be generated from relational identifiers

For example:

```text
customer.id = 1
```

becomes:

```text
http://example.org/customer/1
```

---

### Relational relationships can become semantic graph relationships

```text
customer.id = orders.customer_id
```

can become:

```text
Customer -- placedOrder --> Order
```

---

### The graph can remain completely virtual

The PostgreSQL database can be modified and the changes become visible to SPARQL without exporting or reloading RDF.

---

### The semantic layer can act as an enterprise integration backbone

Multiple operational schemas can map to a common enterprise vocabulary:

```text
CRM Account
      \
       \
SQL Customer ---> Organization
       /
      /
PM Client
```

Applications can then query the canonical enterprise concepts instead of being tightly coupled to the schema of every underlying system.

---

# 37. Potential Extensions

Several natural extensions can be built on top of this demo.

### Multiple relational databases

Add additional PostgreSQL, MySQL or other supported relational sources and explore semantic query federation.

### More complex SQL mappings

Use R2RML logical tables based on SQL queries instead of direct table mappings.

### Multiple operational representations of the same concept

Map concepts such as:

```text
Account
Client
Debtor
Customer
BusinessPartner
```

to a canonical:

```text
Organization
```

class.

### Entity reconciliation

Experiment with shared identifiers across multiple data sources.

### RML

Extend the experiment beyond relational databases to:

* CSV
* JSON
* XML
* API-derived data

### Enterprise ontology

Replace the toy `Customer`/`Order` vocabulary with a richer enterprise semantic model.

### GraphRAG and AI

Use the resulting semantic abstraction as a structured enterprise data layer for:

* GraphRAG
* semantic retrieval
* AI agents
* analytics
* enterprise search

---

# 38. Conceptual Summary

The complete idea behind the demo can be summarized as:

```text
              APPLICATION / USER
                     |
                     | SPARQL
                     v

             SEMANTIC DATA MODEL

              Customer
                 |
                 | placedOrder
                 v
                Order

                     |
                     | R2RML
                     v

             RELATIONAL DATA MODEL

              customer
                 |
                 | PK/FK
                 v
               orders
```

The semantic layer answers:

> What does the enterprise data mean?

The relational layer answers:

> How and where is the data physically stored?

R2RML answers:

> How does the physical representation correspond to the semantic representation?

Ontop then makes this mapping executable by translating semantic SPARQL queries into queries against the underlying relational database.

---

# 39. License

This repository is intended as a small educational and experimental environment for learning R2RML, RDF, SPARQL and Virtual Knowledge Graph concepts.

Add the license appropriate for your project before redistribution.
