\set ON_ERROR_STOP on

CREATE SCHEMA IF NOT EXISTS raw;
CREATE SCHEMA IF NOT EXISTS staging;
CREATE SCHEMA IF NOT EXISTS core;
CREATE SCHEMA IF NOT EXISTS mart;
CREATE SCHEMA IF NOT EXISTS qa;

COMMENT ON SCHEMA raw IS 'Immutable source-shaped tables loaded from Olist CSV files.';
COMMENT ON SCHEMA staging IS 'Typed and lightly standardized views over raw source tables.';
COMMENT ON SCHEMA core IS 'Cleaned facts and conformed dimensions; populated in Stage 5.';
COMMENT ON SCHEMA mart IS 'Business-facing analytical marts; populated in Stage 5.';
COMMENT ON SCHEMA qa IS 'Reusable data-quality functions and validation objects.';

