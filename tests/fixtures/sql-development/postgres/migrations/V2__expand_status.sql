ALTER TABLE accounts ADD COLUMN status varchar(16);
ALTER TABLE accounts ADD CONSTRAINT accounts_status
    CHECK (status IN ('active', 'empty'));
