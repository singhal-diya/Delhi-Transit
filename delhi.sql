use delhi_transit;
Select * from agency limit 5;
Select * from routes limit 5;
select * from stop_times limit 5;

/*
agency -> agency_id PK
calendar -> has no PK
routes -> route_id PK
stop_times -> has no PK
stop -> stop_id
stop_times -> has no Primary key
*/


create index idx_st_trip on stop_times(trip_id);
create index idx_st_stop on stop_times(stop_id);
create index idx_st_seq on stop_times(trip_id,stop_sequence);
create index idx_tr_trip on trips(trip_id);
create index idx_tr_route on trips(route_id);


create view v_routes as
select	
 r.route_id,
 r.agency_id,
 a.agency_name,
 r.route_long_name,
 regexp_replace(r.route_long_name,'(STL)?(UP|DOWN)[0-9]*$','') as base_route,
 case 
	when r.route_long_name like '%DOWN%' Then 'Down'
	when r.route_long_name like '%UP%' Then 'UP'
    else 'unknown' end
from routes r
join agency a on a.agency_id = r.agency_id;

select * from v_routes;

-- v_stop_times - trip_id,stop_id,
-- stop_sequence,arrival_time,departure_time
-- dep_sec, 
-- raw_hour,hour_of_day,
-- is_post_midnight

create view v_stop_times as
select
	st.trip_id,
    st.stop_id,
    st.stop_sequence,
    st.arrival_time,
    st.departure_time,
    time_to_sec(st.departure_time) as dep_sec,
    cast(substring(st.departure_time,1,2) as unsigned) as raw_hour,
    cast(substring(st.departure_time,1,2) as unsigned) mod 24 as hour_of_day,
    case when
    cast(substring(st.departure_time,1,2) as unsigned) > 23 
    then 1 else 0 end as is_post_midnight
from stop_times st;

select
	count(*),
	hour_of_day
from v_stop_times
group by hour_of_day;


-- v_trip_summary - One row per trip
-- Distinct trip id
-- 
create view v_trip_summary as
select
	st.trip_id,
    max(t.route_id) as route_id,
    count(*) as stop_count,
    min(st.dep_sec) as start_sec,-- 6
    max(st.dep_sec) as end_sec,
    round((max(st.dep_sec)-min(st.dep_sec))/60.0,1) as scheduled_minutes,
    min(st.hour_of_day) as start_hour
from v_stop_times st
join (select distinct trip_id, route_id from trips)t
on t.trip_id = st.trip_id
group by st.trip_id;





create view v_segments as
with temp as(
	select
		vts.trip_id,
		vts.stop_sequence,
		vts.dep_sec,
		lag(vts.dep_sec) over (partition by vts.trip_id order by vts.stop_sequence) as prev_sec,
		s.stop_lat,
		s.stop_lon,
		lag(s.stop_lat) over (partition by vts.trip_id order by vts.stop_sequence) as prev_lat,
		lag(s.stop_lon) over (partition by vts.trip_id order by vts.stop_sequence) as prev_lon,
		lag(vts.stop_id) over (partition by vts.trip_id order by vts.stop_sequence) as prev_stop
		from v_stop_times vts
	 join stops s
	 on vts.stop_id = s.stop_id
)
Select trip_id,stop_sequence, prev_stop, dep_sec - prev_sec as elapsed_sec,
 6371 * 2 * ASIN(SQRT(
           POW(SIN(RADIANS(stop_lat - prev_lat)/2),2)
         + COS(RADIANS(prev_lat)) * COS(RADIANS(stop_lat))
         * POW(SIN(RADIANS(stop_lon - prev_lon)/2),2))) as segment_km
from temp
where prev_lat is not null;
     




CREATE OR REPLACE VIEW v_stop_summary AS
SELECT
    p.stop_id, p.stop_name, p.stop_lat, p.stop_lon,
    COUNT(*)                                                     AS stop_events,
    COUNT(DISTINCT t.route_id)                                   AS routes_serving,
    COUNT(DISTINCT st.trip_id)                                   AS trips_serving,
    SUM(CASE WHEN r.agency_id='DTC'   THEN 1 ELSE 0 END)         AS dtc_events,
    SUM(CASE WHEN r.agency_id='DIMTS' THEN 1 ELSE 0 END)         AS dimts_events,
    MIN(st.hour_of_day)                                          AS first_hour,
    MAX(st.hour_of_day)                                          AS last_hour
FROM stops p
JOIN v_stop_times st ON st.stop_id = p.stop_id
JOIN (SELECT DISTINCT trip_id, route_id FROM trips) t ON t.trip_id = st.trip_id
JOIN routes r ON r.route_id = t.route_id
GROUP BY p.stop_id, p.stop_name, p.stop_lat, p.stop_lon;
 
 
 
CREATE OR REPLACE VIEW v_headway AS
WITH origins AS (
    SELECT st.trip_id, st.stop_id, t.route_id, MIN(st.dep_sec) AS dep_sec
    FROM v_stop_times st
    JOIN (SELECT DISTINCT trip_id, route_id FROM trips) t ON t.trip_id = st.trip_id
    WHERE st.stop_sequence = 0 AND st.dep_sec < 86400
    GROUP BY st.trip_id, st.stop_id, t.route_id
)
SELECT route_id, stop_id, dep_sec,
       FLOOR(dep_sec/3600)                                       AS hour_of_day,
       (LEAD(dep_sec) OVER (PARTITION BY route_id, stop_id ORDER BY dep_sec)
        - dep_sec) / 60.0                                        AS headway_min
FROM origins;
 
 CREATE OR REPLACE VIEW v_service AS
SELECT st.trip_id, st.stop_sequence, st.arrival_time,
       CAST(SUBSTRING(st.arrival_time,1,2) AS UNSIGNED) MOD 24 AS hour_of_day,
       t.route_id, st.stop_id
FROM stop_times st
JOIN (SELECT DISTINCT trip_id, route_id FROM trips) t ON t.trip_id = st.trip_id;

CREATE TABLE dim_hour (hour TINYINT PRIMARY KEY, hour_label CHAR(5), period VARCHAR(20));
INSERT INTO dim_hour
WITH RECURSIVE h AS (SELECT 0 n UNION ALL SELECT n+1 FROM h WHERE n < 23)
SELECT n, CONCAT(LPAD(n,2,'0'),':00'),
       CASE WHEN n BETWEEN  6 AND  9 THEN 'Morning Peak'
            WHEN n BETWEEN 10 AND 16 THEN 'Midday'
            WHEN n BETWEEN 17 AND 20 THEN 'Evening Peak'
            WHEN n BETWEEN 21 AND 23 THEN 'Evening'
            ELSE 'Night' END
FROM h;
 
 
CREATE TABLE stop_summary AS SELECT * FROM v_stop_summary;
CREATE TABLE service      AS SELECT * FROM v_service;
 

-- =============================================================================================
--  scalar subqueries in the SELECT list
SELECT
  (SELECT COUNT(*) FROM stops)                                   AS total_stops,
  (SELECT COUNT(DISTINCT base_route) FROM v_routes)              AS real_routes,
  (SELECT COUNT(*) FROM routes)                                  AS route_variants,
  (SELECT COUNT(DISTINCT trip_id) FROM trips)                    AS daily_trips,
  (SELECT COUNT(*) FROM stop_times)                              AS stop_events;

 
 
-- =====================================================================
-- KPI — Route variant inflation           *** REVEAL #1 ***
-- Teaches: REGEXP_REPLACE, why COUNT(*) is not COUNT(DISTINCT thing)
-- =====================================================================
SELECT COUNT(*)                        AS route_rows,
       COUNT(DISTINCT base_route)      AS real_routes,
       ROUND(COUNT(*) / COUNT(DISTINCT base_route), 2) AS variants_per_route
FROM v_routes;

 
-- 3. TABLE — Routes with the most variants
SELECT base_route,
       COUNT(*)                                    AS variants,
       COUNT(DISTINCT direction)                   AS directions,
       GROUP_CONCAT(DISTINCT route_long_name ORDER BY route_long_name SEPARATOR ', ') AS names
FROM v_routes
GROUP BY base_route
HAVING COUNT(*) > 4
ORDER BY variants DESC
LIMIT 15;
 
-- 4. KPI — Operator split
SELECT v.agency_name,
       COUNT(DISTINCT v.base_route)  AS real_routes,
       COUNT(DISTINCT v.route_id)    AS route_variants,
       COUNT(DISTINCT t.trip_id)     AS trips,
       COUNT(DISTINCT st.stop_id)    AS stops_served
FROM v_routes v
JOIN (SELECT DISTINCT trip_id, route_id FROM trips) t ON t.route_id = v.route_id
JOIN stop_times st ON st.trip_id = t.trip_id
GROUP BY v.agency_name;
 
-- 5. TABLE — Hourly service profile
SELECT hour_of_day,
       COUNT(*)                                                       AS trips_starting,
       ROUND(100.0*COUNT(*) / SUM(COUNT(*)) OVER (), 2)               AS pct_of_day,
       SUM(COUNT(*)) OVER (ORDER BY hour_of_day)                      AS cumulative,
       ROUND(100.0*SUM(COUNT(*)) OVER (ORDER BY hour_of_day)
             / SUM(COUNT(*)) OVER (), 1)                              AS cum_pct
FROM v_stop_times
WHERE stop_sequence = 0
GROUP BY hour_of_day
ORDER BY hour_of_day;


SELECT
  SUM(CASE WHEN hour_of_day BETWEEN 7 AND 10 THEN 1 ELSE 0 END)  AS morning_peak,
  SUM(CASE WHEN hour_of_day BETWEEN 17 AND 20 THEN 1 ELSE 0 END) AS evening_peak,
  SUM(CASE WHEN hour_of_day BETWEEN 0 AND 4 THEN 1 ELSE 0 END)   AS night,
  ROUND(100.0*SUM(CASE WHEN hour_of_day BETWEEN 7 AND 10 OR hour_of_day BETWEEN 17 AND 20
                       THEN 1 ELSE 0 END)/COUNT(*),1)            AS peak_share_pct
FROM v_stop_times WHERE stop_sequence = 0;
 
 
-- 7. TABLE — Busiest routes, ranked within each operator
SELECT * FROM (
  SELECT v.agency_name, v.base_route,
         COUNT(DISTINCT t.trip_id)                                AS trips,
         DENSE_RANK() OVER (PARTITION BY v.agency_name
                            ORDER BY COUNT(DISTINCT t.trip_id) DESC) AS rnk
  FROM v_routes v
  JOIN (SELECT DISTINCT trip_id, route_id FROM trips) t ON t.route_id = v.route_id
  GROUP BY v.agency_name, v.base_route
) x
WHERE rnk <= 10
ORDER BY agency_name, rnk;
 
 
-- 8. KPI — Service concentration            *** THE EQUITY HEADLINE ***
WITH s AS (SELECT stop_id, COUNT(*) n FROM stop_times GROUP BY stop_id),
     d AS (SELECT stop_id, n, NTILE(10) OVER (ORDER BY n DESC) decile FROM s)
SELECT decile,
       COUNT(*)                                          AS stops,
       SUM(n)                                            AS stop_events,
       ROUND(100.0*SUM(n)/SUM(SUM(n)) OVER (), 1)        AS pct_of_service
FROM d GROUP BY decile ORDER BY decile;
 
 
-- 9. TABLE — Worst-served stops (that ARE served)
SELECT stop_name, trips_serving, routes_serving, first_hour, last_hour
FROM v_stop_summary
WHERE trips_serving <= 3
ORDER BY trips_serving, stop_name
LIMIT 25;
 
 
-- 10. KPI — Stops with no service at all
SELECT COUNT(*) AS never_served_stops
FROM stops p
LEFT JOIN stop_times st ON st.stop_id = p.stop_id
WHERE st.stop_id IS NULL;
 
-- List them:
SELECT p.stop_id, p.stop_name, p.stop_lat, p.stop_lon
FROM stops p
LEFT JOIN stop_times st ON st.stop_id = p.stop_id
WHERE st.stop_id IS NULL
ORDER BY p.stop_name;
 
 
-- 11. TABLE — Interchange hubs
SELECT p.stop_name,
       COUNT(DISTINCT t.route_id)                        AS routes_serving,
       COUNT(*)                                          AS stop_events,
       COUNT(DISTINCT r.agency_id)                       AS operators
FROM stop_times st
JOIN (SELECT DISTINCT trip_id, route_id FROM trips) t ON t.trip_id = st.trip_id
JOIN routes r ON r.route_id = t.route_id
JOIN stops  p ON p.stop_id  = st.stop_id
GROUP BY p.stop_id, p.stop_name
ORDER BY routes_serving DESC
LIMIT 15;
 
 
-- 12. KPI — Routes per stop distribution
SELECT MIN(routes_serving)                AS min_routes,
       ROUND(AVG(routes_serving),1)       AS avg_routes,
       MAX(routes_serving)                AS max_routes,
       SUM(CASE WHEN routes_serving = 1 THEN 1 ELSE 0 END) AS single_route_stops,
       ROUND(100.0*SUM(CASE WHEN routes_serving = 1 THEN 1 ELSE 0 END)/COUNT(*),1) AS pct_single
FROM v_stop_summary;
 
 
-- 13. KPI — Single-operator dependency
SELECT COUNT(*)                                                    AS served_stops,
       SUM(CASE WHEN dtc_events=0 OR dimts_events=0 THEN 1 ELSE 0 END) AS single_operator,
       ROUND(100.0*SUM(CASE WHEN dtc_events=0 OR dimts_events=0 THEN 1 ELSE 0 END)
             /COUNT(*),1)                                          AS pct
FROM v_stop_summary;
 
 
-- 14. TABLE — Headway variance          *** THE AVERAGES LIE ONE ***
-- Teaches: LEAD, and why mean is the wrong summary statistic
SELECT ROUND(AVG(headway_min),1)     AS mean_headway_min,
       ROUND(STDDEV(headway_min),1)  AS std_dev,
       MIN(headway_min)              AS min_gap,
       MAX(headway_min)              AS max_gap
FROM v_headway
WHERE headway_min IS NOT NULL AND headway_min > 0;
 
 
-- 15. TABLE — Most and least reliable routes by headway consistency
SELECT v.base_route, v.agency_name,
       COUNT(*)                          AS gaps_measured,
       ROUND(AVG(h.headway_min),1)       AS avg_headway,
       ROUND(STDDEV(h.headway_min),1)    AS headway_sd,
       ROUND(STDDEV(h.headway_min)/NULLIF(AVG(h.headway_min),0),2) AS coeff_variation
FROM v_headway h
JOIN v_routes v ON v.route_id = h.route_id
WHERE h.headway_min > 0
GROUP BY v.base_route, v.agency_name
HAVING COUNT(*) >= 30
ORDER BY coeff_variation ASC
LIMIT 20;
-- Lowest coefficient of variation = most evenly spaced service.
-- Flip to DESC for the worst offenders.
 
 
-- =====================================================================
-- 16. TABLE — Service span per route
-- Teaches: MIN/MAX over a derived per-trip table, time arithmetic
-- =====================================================================
SELECT v.base_route, v.agency_name,
       COUNT(DISTINCT ts.trip_id)                          AS trips,
       SEC_TO_TIME(MIN(ts.start_sec))                      AS first_departure,
       SEC_TO_TIME(MAX(ts.start_sec))                      AS last_departure,
       ROUND((MAX(ts.start_sec)-MIN(ts.start_sec))/3600.0,1) AS span_hours
FROM v_trip_summary ts
JOIN v_routes v ON v.route_id = ts.route_id
GROUP BY v.base_route, v.agency_name
HAVING COUNT(DISTINCT ts.trip_id) >= 10
ORDER BY span_hours DESC
LIMIT 20;
-- Network average span: 11.4 hours. Max: 24.0. Min: 0.0 (single trip).
 
 
-- =====================================================================
-- 17. KPI — Trip length distribution
-- Teaches: aggregating an aggregate (two-level GROUP BY)
-- =====================================================================
SELECT MIN(stop_count)              AS shortest_trip,
       ROUND(AVG(stop_count),1)     AS avg_stops,
       MAX(stop_count)              AS longest_trip,
       COUNT(*)                     AS trips
FROM v_trip_summary;
-- min 2 | avg 41.7 | max 169 stops
-- Median is 43, p90 is 60.
 
 
-- =====================================================================
-- 18. KPI — Stop spacing
-- Teaches: haversine in SQL, filtering impossible values
-- =====================================================================
SELECT COUNT(*)                        AS segments,
       ROUND(AVG(segment_km),3)        AS avg_km,
       ROUND(MIN(segment_km),3)        AS min_km,
       ROUND(MAX(segment_km),1)        AS max_km,
       SUM(CASE WHEN segment_km > 5 THEN 1 ELSE 0 END) AS gaps_over_5km
FROM v_segments
WHERE segment_km > 0;
-- avg 0.569 km | median 0.475 | p90 0.98 | max 37.1
-- 37 km between two consecutive stops is a data error worth discussing.
 
 
-- =====================================================================
-- 19. TABLE — Longest routes by distance
-- Teaches: SUM over LAG-derived segments, two-level aggregation
-- =====================================================================
WITH trip_km AS (
    SELECT s.trip_id, SUM(s.segment_km) AS km
    FROM v_segments s
    WHERE s.segment_km > 0 AND s.segment_km < 10   -- exclude data errors
    GROUP BY s.trip_id
)
SELECT v.base_route, v.agency_name,
       ROUND(AVG(tk.km),1)  AS avg_route_km,
       COUNT(*)             AS trips
FROM trip_km tk
JOIN v_trip_summary ts ON ts.trip_id = tk.trip_id
JOIN v_routes v ON v.route_id = ts.route_id
GROUP BY v.base_route, v.agency_name
ORDER BY avg_route_km DESC
LIMIT 20;
-- Network average route length: 22.9 km. Max: 121.3 km.
 
 
-- =====================================================================
-- 20. TABLE — Routes above their OWN operator's average
-- Teaches: CORRELATED subquery. Compare with a plain scalar subquery
--          and ask the class why the answers differ.
-- =====================================================================
SELECT v.agency_name, v.base_route, COUNT(DISTINCT t.trip_id) AS trips
FROM v_routes v
JOIN (SELECT DISTINCT trip_id, route_id FROM trips) t ON t.route_id = v.route_id
GROUP BY v.agency_name, v.base_route
HAVING COUNT(DISTINCT t.trip_id) > (
    SELECT AVG(c) FROM (
        SELECT r2.agency_id, COUNT(DISTINCT t2.trip_id) c
        FROM (SELECT DISTINCT trip_id, route_id FROM trips) t2
        JOIN routes r2 ON r2.route_id = t2.route_id
        GROUP BY r2.agency_id, r2.route_id
    ) y
    WHERE y.agency_id = v.agency_id
)
ORDER BY v.agency_name, trips DESC;
 
 
-- =====================================================================
-- 21. KPI — Directional imbalance
-- Teaches: self-referential GROUP BY, HAVING COUNT(DISTINCT)
-- =====================================================================
SELECT COUNT(*) AS one_direction_only
FROM (
    SELECT base_route
    FROM v_routes
    WHERE direction IN ('Up','Down')
    GROUP BY base_route
    HAVING COUNT(DISTINCT direction) = 1
) x;
-- 82 routes run in ONE direction only. A passenger can travel out
-- but has no scheduled return on that route.
 
-- Direction split overall:
SELECT direction, COUNT(*) FROM v_routes GROUP BY direction;
-- Up 1,478 | Down 1,452 | Unknown 34
 
 
-- =====================================================================
-- 22. TABLE — Hour x operator matrix
-- Teaches: pivot with conditional aggregation
-- =====================================================================
SELECT st.hour_of_day,
       SUM(CASE WHEN r.agency_id='DTC'   THEN 1 ELSE 0 END) AS dtc_trips,
       SUM(CASE WHEN r.agency_id='DIMTS' THEN 1 ELSE 0 END) AS dimts_trips,
       ROUND(100.0*SUM(CASE WHEN r.agency_id='DTC' THEN 1 ELSE 0 END)
             /COUNT(*),1)                                   AS dtc_share_pct
FROM v_stop_times st
JOIN (SELECT DISTINCT trip_id, route_id FROM trips) t ON t.trip_id = st.trip_id
JOIN routes r ON r.route_id = t.route_id
WHERE st.stop_sequence = 0
GROUP BY st.hour_of_day
ORDER BY st.hour_of_day;
-- Does one operator carry more of the night service than the other?
 
 
-- =====================================================================
-- 23. KPI — Post-midnight service
-- Teaches: why hours > 23 exist, and why TIME casting breaks
-- =====================================================================
SELECT COUNT(*)                                              AS post_midnight_events,
       COUNT(DISTINCT trip_id)                               AS trips_affected,
       MAX(departure_time)                                   AS latest_time
FROM v_stop_times
WHERE is_post_midnight = 1;
-- 20,505 stop events past 24:00. Latest: 30:20:51 (6:20am next day).
-- This is why arrival_time is VARCHAR and not TIME.
 
 
-- =====================================================================
-- 24. THE SPEED TEST                        *** REVEAL #2 ***
-- Run LAST. Frame it as an ordinary question:
--   "Which routes are slowest? Compute average speed. Five minutes."
-- Let them work. Let someone present. Then compare all answers.
-- =====================================================================
SELECT r.route_long_name,
       ROUND(SUM(s.segment_km) / (SUM(s.elapsed_sec)/3600.0), 2) AS avg_kmh,
       COUNT(*) AS segments
FROM v_segments s
JOIN v_trip_summary ts ON ts.trip_id = s.trip_id
JOIN routes r ON r.route_id = ts.route_id
WHERE s.elapsed_sec > 0 AND s.segment_km > 0
GROUP BY r.route_id, r.route_long_name
ORDER BY avg_kmh DESC
LIMIT 30;