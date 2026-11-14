CREATE TABLE public.orders (id integer PRIMARY KEY, amount_cents integer NOT NULL CHECK (amount_cents >= 0), label text NOT NULL);
