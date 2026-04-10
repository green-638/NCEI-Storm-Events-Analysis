CREATE VIEW records AS
SELECT
event_id,	
state,
	county_name, 
	YEAR(begin_date) AS year_num,
	MONTH(begin_date) AS month_num,
	event_type,
	damage_property,
	damage_crops
FROM
	events
JOIN event_details
		USING(details_id)
JOIN locations
		USING(loc_id)
JOIN time
		USING(time_id)
WHERE state NOT IN ('AMERICAN SAMOA', 'ATLANTIC NORTH', 'ATLANTIC SOUTH',
	'E PACIFIC', 'GUAM', 'GUAM WATERS', 'GULF OF ALASKA', 'GULF OF MEXICO',
	'HAWAII WATERS', 'LAKE ERIE', 'LAKE HURON', 'LAKE MICHIGAN', 'LAKE ONTARIO',
	'LAKE ST CLAIR', 'LAKE SUPERIOR', 'PUERTO RICO', 'ST LAWRENCE R', 'VIRGIN ISLANDS');
		

