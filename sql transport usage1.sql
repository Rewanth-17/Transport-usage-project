CREATE DATABASE transport_usagedb;
use transport_usagedb;
CREATE TABLE transport_usage (
    record_id            INT PRIMARY KEY,
    city                 VARCHAR(20),
    `mode`               VARCHAR(10),
    `date`               DATE,
    `year`               INT,
    `month`              INT,
    day_of_week          VARCHAR(10),
    is_weekend           TINYINT,
    is_holiday           TINYINT,
    weather              VARCHAR(15),
    temperature_c        DECIMAL(5,1),
    avg_fare_inr         DECIMAL(8,2),
    vehicles_in_service  INT,
    daily_ridership      INT,
    avg_trip_distance_km DECIMAL(5,1),
    peak_hour_share_pct  DECIMAL(5,1),
    on_time_pct          DECIMAL(5,1),
    women_riders_pct     DECIMAL(5,1),
    daily_revenue_inr    BIGINT
);
SELECT *FROM transport_usage;
SELECT COUNT(*) FROM transport_usage;
select* from transport_usage;
SELECT SUM(temperature_c IS NULL) AS null_temp,
       SUM(on_time_pct   IS NULL) AS null_on_time
FROM transport_usage;
SELECT MIN(`date`) AS start_date, MAX(`date`) AS end_date FROM transport_usage;
set sql_safe_updates=0;
UPDATE transport_usage t
JOIN (SELECT city, `mode`, ROUND(AVG(on_time_pct),1) AS avg_ot, ROUND(AVG(temperature_c),1) AS avg_tp
      FROM transport_usage GROUP BY city, `mode`) a
  ON t.city = a.city AND t.`mode` = a.`mode`
SET t.on_time_pct   = COALESCE(t.on_time_pct, a.avg_ot),
    t.temperature_c = COALESCE(t.temperature_c, a.avg_tp)
WHERE t.on_time_pct IS NULL OR t.temperature_c IS NULL;
UPDATE transport_usage
SET city   = TRIM(REPLACE(city, '\r', '')),
    `mode` = TRIM(REPLACE(`mode`, '\r', ''));
UPDATE transport_usage SET city   = NULL WHERE city   = '';
UPDATE transport_usage SET `mode` = NULL WHERE `mode` = '';
SELECT city, COUNT(*) FROM transport_usage GROUP BY city ORDER BY city;

UPDATE transport_usage
SET city = CASE
  WHEN LOWER(REPLACE(city,' ','')) IN ('delhi','newdelhi')      THEN 'New Delhi'
  WHEN LOWER(REPLACE(city,' ','')) IN ('bangalore','bengaluru') THEN 'Banglore'
  WHEN LOWER(REPLACE(city,' ','')) IN ('calcutta','kolkata')     THEN 'Kolkata'
 ELSE CONCAT(UPPER(LEFT(city,1)), LOWER(SUBSTRING(city,2)))
END
WHERE city IS NOT NULL;

SELECT city, `mode`, ROUND(AVG(daily_ridership)) AS avg_daily_riders
FROM transport_usage
WHERE TRIM(IFNULL(city,'')) <> '' AND TRIM(IFNULL(`mode`,'')) <> ''
GROUP BY city, `mode`
ORDER BY city, avg_daily_riders DESC;

UPDATE transport_usage
SET `mode` = CONCAT(UPPER(LEFT(`mode`,1)), LOWER(SUBSTRING(`mode`,2)))
WHERE `mode` IS NOT NULL;
SELECT DISTINCT city FROM transport_usage ORDER BY city;
SELECT DISTINCT `mode` FROM transport_usage;

CREATE VIEW transport_clean AS
SELECT *
FROM transport_usage
WHERE TRIM(IFNULL(city,'')) <> ''
  AND TRIM(IFNULL(`mode`,'')) <> '';



 
-- Q1. Average daily ridership by city and mode;
SELECT city, `mode`, ROUND(AVG(daily_ridership)) AS avg_daily_riders
FROM transport_clean
GROUP BY city, `mode`
ORDER BY city, avg_daily_riders DESC;
 
-- Q2. Year-over-year growth (2023 vs 2024)
WITH yearly AS (
    SELECT city, `mode`, `year`, AVG(daily_ridership) AS avg_riders
    FROM transport_clean
    GROUP BY city, `mode`, `year`
)
SELECT a.city, a.`mode`,
       ROUND(a.avg_riders) AS riders_2023,
       ROUND(b.avg_riders) AS riders_2024,
       ROUND((b.avg_riders - a.avg_riders) / a.avg_riders * 100, 2) AS growth_pct
FROM yearly a
JOIN yearly b ON a.city = b.city AND a.`mode` = b.`mode`
             AND a.`year` = 2023 AND b.`year` = 2024
ORDER BY growth_pct DESC;
 
-- Q3. Weekday vs weekend ridership
SELECT `mode`, is_weekend, ROUND(AVG(daily_ridership)) AS avg_riders
FROM transport_clean
GROUP BY `mode`, is_weekend
ORDER BY `mode`, is_weekend;
 
-- Q4. Holiday impact (% change vs non-holiday)
SELECT city, `mode`,
       ROUND(AVG(CASE WHEN is_holiday = 1 THEN daily_ridership END)) AS holiday_avg,
       ROUND(AVG(CASE WHEN is_holiday = 0 AND is_weekend = 0 THEN daily_ridership END)) AS normal_weekday_avg,
       ROUND((AVG(CASE WHEN is_holiday = 1 THEN daily_ridership END)
            / AVG(CASE WHEN is_holiday = 0 AND is_weekend = 0 THEN daily_ridership END) - 1) * 100, 1) AS pct_change
FROM transport_clean
GROUP BY city, `mode`;
 
-- Q5. Weather impact on ridership and punctuality
SELECT `mode`, weather,
       COUNT(*) AS days,
       ROUND(AVG(daily_ridership)) AS avg_riders,
       ROUND(AVG(on_time_pct), 1)  AS avg_on_time_pct
FROM transport_clean
GROUP BY `mode`, weather
ORDER BY `mode`, avg_riders DESC;
 
-- Q6. Monthly metro ridership trend (all cities)
SELECT `year`, `month`, SUM(daily_ridership) AS total_metro_riders
FROM transport_clean
WHERE `mode` = 'Metro'
GROUP BY `year`, `month`
ORDER BY `year`, `month`;
 
-- Q7. Revenue per passenger by city and mode
SELECT city, `mode`,
       ROUND(SUM(daily_revenue_inr) / SUM(daily_ridership), 2) AS revenue_per_rider_inr,
       ROUND(SUM(daily_revenue_inr) / 10000000, 1)             AS total_revenue_crore
FROM transport_clean
GROUP BY city, `mode`
ORDER BY total_revenue_crore DESC;
 
-- Q8. Rank cities by metro ridership
SELECT city,
       ROUND(AVG(daily_ridership)) AS avg_metro_riders,
       RANK() OVER (ORDER BY AVG(daily_ridership) DESC) AS city_rank
FROM transport_clean
WHERE `mode` = 'Metro'
GROUP BY city;
 
-- Q9. Fleet utilisation: riders per vehicle
SELECT city, `mode`,
       ROUND(AVG(daily_ridership / vehicles_in_service)) AS riders_per_vehicle
FROM transport_clean
GROUP BY city, `mode`
ORDER BY `mode`, riders_per_vehicle DESC;
 
-- Q10. Metro share of total public transport riders by city
SELECT city,
       ROUND(SUM(CASE WHEN `mode` = 'Metro' THEN daily_ridership END) / SUM(daily_ridership) * 100, 1) AS metro_share_pct
FROM transport_clean
GROUP BY city
ORDER BY metro_share_pct DESC;
 
-- Q11. Busiest day of the week per mode
SELECT `mode`, day_of_week, ROUND(AVG(daily_ridership)) AS avg_riders
FROM transport_clean
GROUP BY `mode`, day_of_week
ORDER BY `mode`, avg_riders DESC;
 

 
-- Q12. Fare increase 2023 -> 2024 by city and mode
SELECT city, `mode`,
       ROUND(AVG(CASE WHEN `year` = 2023 THEN avg_fare_inr END), 2) AS fare_2023,
       ROUND(AVG(CASE WHEN `year` = 2024 THEN avg_fare_inr END), 2) AS fare_2024
FROM transport_clean
GROUP BY city, `mode`;