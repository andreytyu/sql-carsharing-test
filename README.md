## Generating trips from telematic

Clone the repo:

```
git clone https://github.com/andreytyu/sql-carsharing-test.git
cd sql-carsharing-test
```

**Copy the data to the directory and name in data.csv**

Start a container with a PostGIS-enabled database as follows:
```
docker run -p 9900:5432 -v $(pwd):/data --name taxi-postgis -e POSTGRES_PASSWORD=password -d mdillon/postgis
```
Database `postgres` with user `postgres` and password `password` will start on `localhost:9900`, create a `/data` volume and mount all data from current directory there

Connect to the database:
```
docker run -v $(pwd):/data  -it --link taxi-postgis:postgres --rm postgres     sh -c 'exec psql -h "$POSTGRES_PORT_5432_TCP_ADDR" -p "$POSTGRES_PORT_5432_TCP_PORT" -U postgres'
```

Run [this script](https://github.com/andreytyu/sql-carsharing-test/blob/master/data_import.sql) to import the data to the database:

```
\i /data/data_import.sql
```

[Process](https://github.com/andreytyu/sql-carsharing-test/blob/master/data_processing.sql) the data:

```
\i /data/data_processing.sql
```

This will create the table `trips` with following fields:

```
trip_id bigint -- trip id
tmatic_id numeric -- car id
start_time timestamp -- time when the car was ordered
movement_start_time timestamp -- time when the car started moving
start_point geometry -- start point of the trip
stop_time timestamp -- time when the order ended
end_point geometry -- end point of the trip
trip_geom geometry -- the track of the trip LineString
trip_length numeric -- the trip length
```