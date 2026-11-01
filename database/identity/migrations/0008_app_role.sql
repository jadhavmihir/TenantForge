-- database role for the identity api. its login joins this role later.
-- it can run procedures and nothing else. this works through ownership chaining (procedures and tables
-- are both owned by dbo), so don't build dynamic sql inside a procedure, it breaks the chain.

CREATE ROLE tf_app_identity;
GO

GRANT EXECUTE ON SCHEMA::iam  TO tf_app_identity;
GRANT EXECUTE ON SCHEMA::sync TO tf_app_identity;
GO

-- first layer of audit immutability, the trigger is the second
DENY UPDATE, DELETE ON SCHEMA::audit TO tf_app_identity;
DENY SELECT ON OBJECT::iam.UserCredentials TO tf_app_identity;
GO
