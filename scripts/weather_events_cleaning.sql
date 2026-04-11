USE weather_events;

-- import datasets into single table

-- fix date format
ALTER TABLE storm_events
ADD begin_date DATETIME NULL,
ADD end_date DATETIME NULL;

UPDATE storm_events
SET begin_date = STR_TO_DATE(begin_date_time, '%d-%b-%y %T'),
	end_date = STR_TO_DATE(end_date_time, '%d-%b-%y %T');


-- convert damage cost to number
DROP FUNCTION IF EXISTS convert_cost;

DELIMITER //

CREATE FUNCTION convert_cost(left_num CHAR(4), right_num CHAR(2), unit CHAR(1))
	RETURNS VARCHAR(255) DETERMINISTIC
	BEGIN
		IF unit = 'K'
		THEN
			IF LENGTH(left_num) < 4
			THEN
				RETURN CONCAT(left_num, '000') + CONCAT(right_num, '0');
			ELSE
				RETURN left_num + CONCAT(right_num, '0');
			END IF;
		ELSEIF unit = 'M'
		THEN
			RETURN CONCAT(left_num, '000000') + CONCAT(right_num, '0000');
		ELSE
			RETURN CONCAT(left_num, '000000000') + CONCAT(right_num, '000000');
		END IF;
	END //

DELIMITER ;

UPDATE storm_events
SET damage_property = convert_cost (
	REGEXP_SUBSTR(damage_property, '^\\d+'),
	REGEXP_SUBSTR(REGEXP_REPLACE(damage_property, '[KMB]$', ''), '\\d+$'),
	REGEXP_SUBSTR(damage_property, '[KMB]$')
	),
	damage_crops = convert_cost (
	REGEXP_SUBSTR(damage_crops, '^\\d+'),
	REGEXP_SUBSTR(REGEXP_REPLACE(damage_crops, '[KMB]$', ''), '\\d+$'),
	REGEXP_SUBSTR(damage_crops, '[KMB]$')
	);
	
ALTER TABLE storm_events
MODIFY COLUMN damage_property BIGINT,
MODIFY COLUMN damage_crops BIGINT
-- remove category column- nearly blank
DROP COLUMN category;



-- split into tables

-- time table
CREATE TABLE time (
	time_id INT auto_increment NOT NULL,
	begin_date DATETIME NULL,
	end_date DATETIME NULL,
	CONSTRAINT time_PK PRIMARY KEY (time_id)
)
ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO time (begin_date, end_date)
SELECT DISTINCT begin_date, end_date
FROM storm_events 


-- locations table
CREATE TABLE locations (
	loc_id INT auto_increment NOT NULL,
	state_fips VARCHAR(255) NULL,
	state VARCHAR(255) NULL,
	county_fips VARCHAR(255) NULL,
	county_name VARCHAR(255) NULL,
	loc_type VARCHAR(255) NULL,
	begin_location VARCHAR(255) NULL,
	timezone VARCHAR(255) NULL,
	wfo CHAR(3) NULL,
	CONSTRAINT location_PK PRIMARY KEY (loc_id)
)
ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO locations (state_fips, state, county_fips,
	county_name, loc_type, begin_location, timezone, wfo)
SELECT DISTINCT state_fips, state, cz_fips, cz_name, cz_type, 
	begin_location, cz_timezone, wfo
FROM storm_events;

-- get valid counties
CREATE VIEW valid_counties AS (
	WITH all_counties AS (
		SELECT DISTINCT loc_id, state, REPLACE(REPLACE(county_name, ' COUNTY', ''), ' PARISH', '') AS county
		FROM locations
	)
		
	SELECT loc_id, state, county
	FROM all_counties
	INNER JOIN state_counties USING(state, county)
)
	

-- event_details table
CREATE TABLE event_details (
	details_id INT auto_increment NOT NULL,
	event_type VARCHAR(255) NULL,
	magnitude_type CHAR(2) NULL,
	flood_cause VARCHAR(255) NULL,
	tor_f_scale CHAR(3) NULL,
	begin_azimuth VARCHAR(255) NULL,
	end_azimuth VARCHAR(255) NULL,
	CONSTRAINT event_details_PK PRIMARY KEY (details_id)
)
ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_0900_ai_ci;

INSERT INTO event_details (event_type,
	magnitude_type, flood_cause, tor_f_scale, begin_azimuth, end_azimuth)
SELECT DISTINCT event_type, magnitude_type,
	flood_cause, tor_f_scale, begin_azimuth, end_azimuth
FROM storm_events;


-- events table (facts)
ALTER TABLE storm_events 
MODIFY COLUMN event_id INT;

CREATE TABLE events (
	episode_id INT auto_increment NOT NULL,
	event_id INT NOT NULL,
	details_id INT NOT NULL,
	time_id INT NOT NULL,
	loc_id INT NOT NULL,
	injuries_direct INT NULL,
	injuries_indirect INT NULL,
	deaths_direct INT NULL,
	deaths_indirect INT NULL,
	damage_property BIGINT NULL,
	damage_crops BIGINT NULL,
	magnitude DECIMAL(5,2) NULL,
	tor_length DECIMAL(4,2) NULL,
	tor_width INT NULL,
	begin_range DECIMAL(5,2) NULL,
	end_range DECIMAL(5,2) NULL,
	CONSTRAINT events_pk
		PRIMARY KEY (episode_id, event_id,
		details_id, time_id, loc_id)
)
ENGINE=InnoDB
DEFAULT CHARSET=utf8mb4
COLLATE=utf8mb4_0900_ai_ci;

-- insert data into facts table
INSERT INTO events 
WITH 
	cte1 AS (
	SELECT se.episode_id, se.event_id, l.loc_id, se.event_type, se.injuries_direct,
		se.injuries_indirect, se.deaths_direct, se.deaths_indirect,
		se.damage_property, se.damage_crops, se.magnitude, se.magnitude_type,
		se.flood_cause, se.tor_f_scale, se.tor_length, se.tor_width,
		se.begin_range, se.begin_azimuth, se.end_range, se.end_azimuth,
		se.begin_date, se.end_date 
	FROM storm_events se
	JOIN locations l 
			ON se.state_fips = l.state_fips AND
			se.cz_fips = l.county_fips AND
			se.cz_type = l.loc_type AND
			se.begin_location = l.begin_location AND
			se.cz_timezone = l.timezone AND
			se.wfo = l.wfo AND 
			se.state = l.state AND
			se.cz_name = l.county_name 
	),

	cte2 AS (
		SELECT c1.episode_id, c1.event_id, c1.loc_id, ed.details_id, c1.injuries_direct,
			c1.injuries_indirect, c1.deaths_direct, c1.deaths_indirect,
			c1.damage_property, c1.damage_crops, c1.magnitude,
			c1.tor_length, c1.tor_width, c1.begin_range, c1.end_range,
			c1.begin_date, c1.end_date 
		FROM cte1 c1
		JOIN event_details ed
			ON c1.event_type = ed.event_type AND
			c1.magnitude_type = ed.magnitude_type AND
			c1.flood_cause  = ed.flood_cause AND
			c1.tor_f_scale = ed.tor_f_scale AND
			c1.begin_azimuth = ed.begin_azimuth AND
			c1.end_azimuth = ed.end_azimuth 
	),
	
	cte3 AS (
		SELECT c2.episode_id, c2.event_id, c2.loc_id, c2.details_id, t.time_id, c2.injuries_direct,
		c2.injuries_indirect, c2.deaths_direct, c2.deaths_indirect,
		c2.damage_property, c2.damage_crops, c2.magnitude, c2.tor_length,
		c2.tor_width, c2.begin_range, c2.end_range
		FROM cte2 c2
			JOIN time t
				ON c2.begin_date = t.begin_date AND
					c2.end_date = t.end_date
	
)
				
SELECT episode_id, event_id, details_id, time_id, loc_id, injuries_direct, injuries_indirect, deaths_direct,
	deaths_indirect, damage_property, damage_crops, magnitude, tor_length, tor_width, begin_range, end_range
FROM cte3

-- add foreign key constraints
ALTER TABLE weather_events.events
ADD CONSTRAINT events_event_details_FK
FOREIGN KEY (details_id) REFERENCES weather_events.event_details(details_id);

ALTER TABLE weather_events.events
ADD CONSTRAINT events_locations_FK
FOREIGN KEY (loc_id) REFERENCES weather_events.locations(loc_id);

ALTER TABLE weather_events.events
ADD CONSTRAINT events_time_FK
FOREIGN KEY (time_id) REFERENCES weather_events.`time`(time_id);
