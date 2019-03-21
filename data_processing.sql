CREATE TABLE trips as (
-- creating lags for in_use field 
WITH a AS (
    SELECT
      *,
      lag(in_use, 1) OVER (PARTITION BY tmatic_id ORDER BY gps_time ASC) AS in_use_lag
    FROM
      telematic
)
-- selecting rows where the in_use status have changed
,b AS (
    SELECT
      tmatic_id,
      gps_time,
      CASE
        WHEN (in_use AND NOT in_use_lag) THEN 'start'
        WHEN (NOT in_use AND in_use_lag) THEN 'end'
      END AS action_type
    FROM
      a
    WHERE
      (in_use AND NOT in_use_lag)
      OR (NOT in_use AND in_use_lag)
)
-- creting leading 
,c AS (
    SELECT
      *,
      lead(gps_time) OVER w AS lead_time,
      lead(action_type) OVER w AS lead_type
    FROM
      b
    WINDOW w AS (PARTITION BY tmatic_id ORDER BY gps_time ASC)
)
-- creating separate trips with start/end times and ids
,d AS (
    SELECT
      row_number() OVER () AS trip_id,
      tmatic_id,
      gps_time as start_time,
      lead_time as stop_time,
      action_type,
      lead_type
    FROM
      c
    WHERE
      action_type = 'start' AND lead_type = 'end'
)
-- calculating distance to the start point for each point of each trip
,e AS (
    SELECT
      st_distance(first_value(st_transform(geom, 32637))
                  OVER (
                    PARTITION BY trip_id
                    ORDER BY gps_time ASC), st_transform(geom, 32637)) AS distance_from_start,
      a.gps_time,
      a.geom,
      d.*
    FROM
      d, a
    WHERE
      a.gps_time >= d.start_time
      AND a.gps_time < d.stop_time
      AND a.tmatic_id = d.tmatic_id
)
-- selecting the movement start time (distance from start exceeding 10 meters)
,f AS (
    SELECT
      trip_id,
      min(gps_time) AS movement_start_time
    FROM
      e
    WHERE
      distance_from_start > 10
    GROUP BY
      trip_id
)

-- joining the movement start times to trips
,g AS (
    SELECT
      d.*,
      f.movement_start_time
    FROM
      d, f
    WHERE
      d.trip_id = f.trip_id
)
-- generating an array of all points for each trip
,h AS (
    SELECT
      g.trip_id,
      array_agg(geom ORDER BY a.gps_time ASC) AS track_points
    FROM
      g, a
    WHERE
      a.gps_time >= g.start_time
      AND a.gps_time < g.stop_time
      AND a.tmatic_id = g.tmatic_id
    GROUP BY
      g.trip_id
)
-- final selection: creating LineStrings and start/end Points for each trip
SELECT
  g.trip_id,
  g.tmatic_id,
  g.start_time,
  g.movement_start_time,
  track_points[1] AS start_point,
  g.stop_time,
  h.track_points[array_length(h.track_points, 1)] AS end_point,
  st_makeline(h.track_points) AS trip_geom,
  round(st_length(st_transform(st_makeline(h.track_points), 32637))::NUMERIC, 2) AS trip_length
FROM
  h, g
WHERE
  g.trip_id = h.trip_id
);