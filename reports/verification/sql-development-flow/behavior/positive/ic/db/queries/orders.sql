SELECT id, amount_cents, label FROM public.orders WHERE amount_cents >= :'minimum'::integer ORDER BY amount_cents DESC, id ASC;
