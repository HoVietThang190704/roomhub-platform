-- =============================================================================
-- RoomHub Platform - Initial PostgreSQL Extensions, Schemas and Roles Setup
-- =============================================================================

-- Enable extensions
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
CREATE EXTENSION IF NOT EXISTS "postgis";

-- 1. Create service schemas (schema-per-service)
CREATE SCHEMA IF NOT EXISTS identity;
CREATE SCHEMA IF NOT EXISTS listing;
CREATE SCHEMA IF NOT EXISTS booking;
CREATE SCHEMA IF NOT EXISTS payment;
CREATE SCHEMA IF NOT EXISTS notification;

-- 2. Create service-specific roles (local dev defaults - override in production)
DO
$do$
BEGIN
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'identity_app') THEN
      CREATE ROLE identity_app WITH LOGIN PASSWORD 'change_me_local';
   END IF;
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'listing_app') THEN
      CREATE ROLE listing_app WITH LOGIN PASSWORD 'change_me_local';
   END IF;
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'booking_app') THEN
      CREATE ROLE booking_app WITH LOGIN PASSWORD 'change_me_local';
   END IF;
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'payment_app') THEN
      CREATE ROLE payment_app WITH LOGIN PASSWORD 'change_me_local';
   END IF;
   IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'notification_app') THEN
      CREATE ROLE notification_app WITH LOGIN PASSWORD 'change_me_local';
   END IF;
END
$do$;

-- 3. Grant schema permissions
GRANT ALL ON SCHEMA identity TO identity_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA identity GRANT ALL ON TABLES TO identity_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA identity GRANT ALL ON SEQUENCES TO identity_app;

GRANT ALL ON SCHEMA listing TO listing_app;
GRANT USAGE ON SCHEMA public TO listing_app; -- needed for PostGIS functions/types
ALTER DEFAULT PRIVILEGES IN SCHEMA listing GRANT ALL ON TABLES TO listing_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA listing GRANT ALL ON SEQUENCES TO listing_app;

GRANT ALL ON SCHEMA booking TO booking_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA booking GRANT ALL ON TABLES TO booking_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA booking GRANT ALL ON SEQUENCES TO booking_app;

GRANT ALL ON SCHEMA payment TO payment_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA payment GRANT ALL ON TABLES TO payment_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA payment GRANT ALL ON SEQUENCES TO payment_app;

GRANT ALL ON SCHEMA notification TO notification_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA notification GRANT ALL ON TABLES TO notification_app;
ALTER DEFAULT PRIVILEGES IN SCHEMA notification GRANT ALL ON SEQUENCES TO notification_app;
