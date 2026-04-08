-- query 1: total weather event count per year
SELECT
	CAST(YEAR(begin_date) AS CHAR(4)) AS `year`,
	COUNT(event_id) AS event_count
FROM
	events
JOIN time
		USING(time_id)
GROUP BY
	CAST(YEAR(begin_date) AS CHAR(4));
	
	
-- query 2: average weather event count per month
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


-- query 3: most common weather events overall counted in each state 
CREATE VIEW state_weather_events AS
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
HAVING
	event_type IN ('Thunderstorm Wind', 'Hail',
	'Flash Flood', 'High Wind', 'Winter Weather')
ORDER BY
	state;
	
	
-- query 4: avg damage per minute for each event type
WITH q4_cte AS (
SELECT
		event_type,
		damage_property + damage_crops AS total_damage,
		begin_date,
		end_date,
		TIMESTAMPDIFF(MINUTE, begin_date, end_date) AS minutes
FROM
		events
JOIN time
		USING(time_id)
JOIN event_details
		USING(details_id)
WHERE
		TIMESTAMPDIFF(MINUTE, begin_date, end_date) > 0
	AND damage_property + damage_crops > 0
ORDER BY
		end_date - begin_date DESC
)

SELECT
	event_type,
	ROUND(AVG(total_damage / minutes), 2) AS damage_per_minute
FROM
	q4_cte
GROUP BY
	event_type
-- remove outliers
HAVING
	COUNT(event_type) > 10
ORDER BY
	ROUND(AVG(total_damage / minutes), 2) DESC;


-- query 5: avg injuries/deaths per hour for each event type
WITH q5_cte AS (
SELECT
		event_type,
		injuries_direct + injuries_indirect + deaths_direct + deaths_indirect AS total,
		begin_date,
		end_date,
		TIMESTAMPDIFF(HOUR, begin_date, end_date) AS hours
FROM
		events
JOIN time
		USING(time_id)
JOIN event_details
		USING(details_id)
WHERE
		TIMESTAMPDIFF(HOUR, begin_date, end_date) > 0
	AND injuries_direct + injuries_indirect + deaths_direct + deaths_indirect > 0
ORDER BY
		end_date - begin_date DESC
)

SELECT
	event_type,
	ROUND(AVG(total / hours), 2) AS accidents_per_hour
FROM
	q5_cte
GROUP BY
	event_type
ORDER BY
	ROUND(AVG(total / hours), 2) DESC;