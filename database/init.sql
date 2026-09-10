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