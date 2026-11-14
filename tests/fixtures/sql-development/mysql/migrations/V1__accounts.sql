CREATE TABLE accounts (
    id integer PRIMARY KEY,
    name varchar(80) NOT NULL,
    credit_cents integer NOT NULL CHECK (credit_cents >= 0)
) ENGINE=InnoDB;
INSERT INTO accounts (id, name, credit_cents) VALUES
    (1, 'Alice', 100), (2, 'Bob', 0);
