-- creating table, copying data from csv
create table telematic ("tmatic_id" numeric, "gps_time" timestamp,"lon" numeric,"lat" numeric, "in_use" boolean);

copy telematic from '/data/data.csv' delimiter ',' csv header;

-- creating geometry columng from latitude/longitude, dropping spare columns
SELECT AddGeometryColumn('telematic', 'geom', 4326, 'POINT',2);

UPDATE telematic
SET geom = ST_SetSRID(ST_Point(lon, lat), 4326);

ALTER TABLE telematic 
DROP COLUMN lon, DROP COLUMN lat;