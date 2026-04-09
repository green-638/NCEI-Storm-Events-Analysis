-- query 1: total weather event count per year
CREATE VIEW annual_event_count_view AS
SELECT
	CAST(YEAR(begin_date) AS CHAR(4)) AS `year`,
	COUNT(event_id) AS event_count
FROM
	events
JOIN time
		USING(time_id)
GROUP BY
	CAST(YEAR(begin_date) AS CHAR(4));


-- query 2: total damage and total events
CREATE VIEW total_damage_view AS
SELECT SUM(damage_property + damage_crops) AS total_cost
FROM events
JOIN event_details USING(details_id)  

CREATE VIEW total_events AS
SELECT COUNT(*) AS total_event_count
FROM events
	
	
-- query 3: average weather event count per month
CREATE VIEW avg_monthly_event_count_view AS
WITH q3_cte AS (
	SELECT
		YEAR(begin_date) AS `year`,
		MONTH(begin_date) AS `month`, 
		COUNT(event_id) AS event_count
	FROM
		events
	JOIN time
			USING(time_id)
	GROUP BY
		YEAR(begin_date),
		MONTH(begin_date)
)

SELECT
	`month`,
	ROUND(AVG(event_count), 0) AS avg_count
FROM
	q3_cte
GROUP BY
	`month`;


-- query 4: # of weather events in each state
CREATE VIEW state_event_count_view AS
SELECT
	state,
	event_type,
	COUNT(event_id) AS event_count
FROM
	events
JOIN event_details
		USING(details_id)
JOIN locations
		USING(loc_id)
GROUP BY
	state,
	event_type
ORDER BY
	state;
	
	
-- query 5: avg damage per minute for each event type
CREATE VIEW avg_damage_per_min AS
WITH q4_cte AS (
SELECT
		event_type,
		TIMESTAMPDIFF(MINUTE, begin_date, end_date) AS minutes,
		damage_property + damage_crops AS total_damage,
		(damage_property + damage_crops) / 
			TIMESTAMPDIFF(MINUTE, begin_date, end_date) AS damage_per_minute
FROM
		events
JOIN time
		USING(time_id)
JOIN event_details
		USING(details_id)
WHERE
		TIMESTAMPDIFF(MINUTE, begin_date, end_date) > 0
	AND damage_property + damage_crops > 0
)

SELECT
	event_type,
	ROUND(AVG(damage_per_minute), 2) AS avg_damage_per_minute
FROM
	q4_cte
GROUP BY
	event_type
-- remove outliers
HAVING
	COUNT(event_type) > 10
ORDER BY
	ROUND(AVG(damage_per_minute), 2) DESC;


