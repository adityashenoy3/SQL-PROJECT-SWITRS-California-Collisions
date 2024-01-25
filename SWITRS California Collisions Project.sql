/*
DATABASE SOURCE: https://www.kaggle.com/datasets/alexgude/california-traffic-collision-data-from-switrs
The data dictionary for each table can be found here: https://tims.berkeley.edu/help/SWITRS.php
This data has been collected by California Highway Patrol as required by State of California, and is called Statewide Integrated Traffic Records System (SWITRS)  

This project has a lot of potential since the data covers a vast range of collisions dating from 01/01/2001 to 06/03/2021. 
*/

-- Uncomment the code below to check whether tables have been properly imported

/* 
SELECT * FROM collisions
SELECT * FROM parties
SELECT * FROM victims
SELECT * FROM case_ids 
*/

/*

First, I'll start by doing some basic data exploration and find some preliminary stats and counts like total collisions in each year,
common collision types, and how many collisions included involvement of alchohol.

*/

-- 1. How many collisions occurred in each year?

SELECT strftime('%Y', collision_date) as Year, COUNT(*) as Total_Collisions
FROM collisions
GROUP BY Year;

-- 2. What is the average number of victims in a collision?

SELECT AVG(killed_victims + injured_victims) as Average_Victims
FROM collisions;

-- 3. Percentage of collisions with injured victims and killed victims

SELECT
    COUNT(case_id) as Total_Collisions,  
    ROUND(SUM(CASE WHEN injured_victims > 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 3) as Percentage_With_Injuries,
    ROUND(SUM(CASE WHEN killed_victims > 0 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 3) as Percentage_With_Fatalities
FROM collisions;

-- 4. Which jurisdiction has the highest number of collisions?

SELECT jurisdiction, COUNT(*) as Total_Collisions
FROM collisions
GROUP BY jurisdiction
ORDER BY Total_Collisions DESC
LIMIT 5;

/* 

According to the data dictionary linked in the beginning, the jurisdiction values are codes for law enforcement agenicies. I will not be delving too deep in
jurisdiction codes

*/

-- 5. What are the top 10 collision types 

SELECT type_of_collision, COUNT(*) as Frequency
FROM collisions
WHERE type_of_collision IS NOT NULL 
GROUP BY type_of_collision
ORDER BY Frequency DESC
LIMIT 8;

-- 6. Proportion of cases where alcohol was involved
SELECT 
    ROUND((COUNT(*) * 100.0 / (SELECT COUNT(*) FROM collisions)), 2) as Alcohol_Involvement
FROM collisions
WHERE alcohol_involved = 1;

-- 7. Distribution of victim age groups (Children: 0-20, Youth: 20-35, Middle-Aged: 36-65, Elderly: 66 < )   

-- Uncomment the below code when running for the first time. About 150 rows had the age as 999, so I have replaced those with NULL values

/* 
SELECT victim_age, COUNT(*) AS Frequency
FROM victims 
GROUP BY victim_age


UPDATE victims
SET victim_age = NULL
WHERE victim_age > 125;

*/

SELECT 
    CASE 
        WHEN victim_age BETWEEN 0 AND 20 THEN 'Children'
        WHEN victim_age BETWEEN 21 AND 35 THEN 'Youth'
        WHEN victim_age BETWEEN 36 AND 65 THEN 'Middle-Aged'
        WHEN victim_age > 65 THEN 'Elderly'
        ELSE 'Unknown' -- For NULL or any age not covered in the ranges
    END as Victim_Age_Group,
    COUNT(*) as Frequency
FROM victims
GROUP BY Victim_Age_Group;

-- 8. Victims distribution by gender

SELECT 
    CASE 
        WHEN victim_sex = 'male' THEN 'Male'
        WHEN victim_sex = 'female' THEN 'Female'
        ELSE 'Other'
    END as Gender,
    COUNT(*) as Total
FROM victims
GROUP BY Gender;

/*

Now that I have looked at some very basic stats, counts and aggregates in the data, I will delve deeper and try to get some 
more insights into the collisions. Some questions I though of were:


-- Motorcyclists have a bad reputation of being risky and unsafe, possibly causing more collisions. I wanted to know if this was true. Are motorcyclists really
the main cause of more accidents?
-- I initally had thought that weekdays would have more number of accidents since so many people commute to work by driving/"Uber"-ing. Or it could be that more accidents
on weekeds as on those days, people are out enjoying, possibly inebriated, leading to more collisions.
-- Does age has to do with DUI accidents? Young people are usually more likely to cause reckless accidents.
 

*/

-- 9. Which vehichle types lead to the most injuries/deaths on average?

SELECT 
    CASE
        WHEN statewide_vehicle_type_at_fault IN ('passenger car', 'passenger car with trailer', 'pickup or panel truck', 'pickup or panel truck with trailer') THEN 'Passenger Vehicles'
        WHEN statewide_vehicle_type_at_fault IN ('truck or truck tractor', 'truck or truck tractor with trailer', 'other bus') THEN 'Commercial Vehicles'
        WHEN statewide_vehicle_type_at_fault IN ('motorcycle or scooter', 'moped') THEN 'Two-Wheelers'
        WHEN statewide_vehicle_type_at_fault IN ('schoolbus', 'other bus') THEN 'Buses'
        ELSE statewide_vehicle_type_at_fault
    END as Vehicle_Category,
    COUNT(*) as Frequency,
    ROUND(AVG(killed_victims + injured_victims), 2) as Average_Victims
FROM collisions
WHERE statewide_vehicle_type_at_fault IS NOT NULL AND statewide_vehicle_type_at_fault != 22
GROUP BY Vehicle_Category
ORDER BY Frequency DESC;

-- 10. Are DUI collissions more prevalent on particular days?

SELECT 
    CASE strftime('%w', collision_date)
        WHEN '0' THEN 'Sunday'
        WHEN '1' THEN 'Monday'
        WHEN '2' THEN 'Tuesday'
        WHEN '3' THEN 'Wednesday'
        WHEN '4' THEN 'Thursday'
        WHEN '5' THEN 'Friday'
        WHEN '6' THEN 'Saturday'
    END as Day_of_Week,
    (COUNT(*) * 100.0 / (SELECT COUNT(*) FROM collisions WHERE alcohol_involved = 1)) as DUI_Percentage
FROM collisions
WHERE alcohol_involved = 1
GROUP BY Day_of_Week
ORDER BY DUI_Percentage DESC;

-- 11. What is the correlation between road conditions and collisions severity?

SELECT road_condition_1, collision_severity, COUNT(*) as Total
FROM collisions 
WHERE road_condition_1 IS NOT NULL AND collision_severity IS NOT NULL
GROUP BY road_condition_1, collision_severity
ORDER BY Total DESC;

-- 12. Which parties are most commonly involved in fatal collisions?

SELECT p.party_type, COUNT(*) as Total
FROM parties p
JOIN collisions c ON p.case_id = c.case_id
WHERE c.collision_severity = 'fatal'
GROUP BY p.party_type
ORDER BY Total DESC;

-- 13. What is the correlation between the age of the party at fault and the involvement of aclohol?
SELECT 
    CASE 
        WHEN p.party_age <= 20 THEN '0-20'
        WHEN p.party_age BETWEEN 21 AND 35 THEN '21-35'
        WHEN p.party_age BETWEEN 36 AND 65 THEN '36-65'
        WHEN p.party_age > 65 THEN '>65'
        ELSE 'Unknown' 
    END as Faulter_Age_Range,
    COUNT(*) as Total_DUI_Involvement
FROM collisions c
JOIN parties p ON c.case_id = p.case_id
WHERE c.alcohol_involved = 1 AND p.at_fault = 1
GROUP BY Age_Range;

-- 14. What has been the trend for various collisions over the years?

SELECT 
    strftime('%Y', collision_date) as Year,
    SUM(CASE WHEN pedestrian_collision = 1 THEN 1 ELSE 0 END) as Pedestrian_Collisions,
    SUM(CASE WHEN motorcycle_collision = 1 THEN 1 ELSE 0 END) as Motorcycle_Collisions,
    SUM(CASE WHEN truck_collision = 1 THEN 1 ELSE 0 END) as Truck_Collisions,
    SUM(CASE WHEN bicycle_collision = 1 THEN 1 ELSE 0 END) as Bicycle_Collisions,
    COUNT(*) as Total_Collisions
FROM collisions
GROUP BY Year
ORDER BY Year;

-- 15. How do the characteristics of parties and victims, such as average age and sobriety, correlate with the severity of traffic collisions?

SELECT 
    c.collision_severity,
    AVG(p.party_age) as Avg_Party_Age,
    AVG(v.victim_age) as Avg_Victim_Age,
    SUM(CASE WHEN p.party_sobriety = 'had been drinking, under influence' THEN 1 ELSE 0 END) as DUI_Count,
    SUM(CASE WHEN p.at_fault = 1 THEN 1 ELSE 0 END) as At_Fault_Count,
    COUNT(*) as Total_Collisions
FROM collisions c
JOIN parties p ON c.case_id = p.case_id
JOIN victims v ON c.case_id = v.case_id
GROUP BY c.collision_severity
ORDER BY Total_Collisions DESC;

/*

Inferences:
Turns out motorcyclists are NOT the the ones most involved in accidents, it is actually more passenger cars. This could be due to the sheer number of 
passenger cars vs motorcycles in use.
Also, not surprisingly, most accidents happen over the weekend and not on weekdays. This means there is an alarming number of people who are possibly
engaging in drinking and driving. Please DO NOT DRINK AND DRIVE.

I then explored insights into the parties involved in accidents, trying to understand what the demographics of the faulters were, and those of the victims.
I wanted to know the effect of age, alcohol, weather and other conditions which affect collisions and thier severity.

Next, I wanted to get into the specific details of things and try to pinpoint answers to some questions I had.

-- Are cars from some manufacturers/brands more dangerous than others? Are they involved in more crashes or more importantly, fatally.
-- Are there some cars that buyers are better off not buying?
-- What time of day do we see most crashes? Do truck crashes happen at different times than bicycle crashes?
-- What are the most dangerous roads in California? How about an interactive map of the collisions on Tableau

*/

-- 16. What is the risk profile of various vehicle makes?

SELECT 
    p.vehicle_make,
    COUNT(*) as Collision_Frequency,
    AVG(CASE 
            WHEN c.collision_severity = 'fatal' THEN 4
            WHEN c.collision_severity = 'severe injury' THEN 3
            WHEN c.collision_severity = 'other injury' OR c.collision_severity = 'property damage only' THEN 2
            ELSE 1 
        END) as Average_Severity_Score,
    AVG(c.killed_victims + c.injured_victims) as Average_Victim_Impact,
    SUM(CASE WHEN p.party_sobriety = 'had been drinking, under influence' THEN 1 ELSE 0 END) as DUI_Involvement,
    AVG(p.party_age) as Average_Driver_Age,
    SUM(CASE WHEN p.at_fault = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*) as Percentage_At_Fault
FROM parties p
JOIN collisions c ON p.case_id = c.case_id
WHERE p.vehicle_make IS NOT NULL
GROUP BY p.vehicle_make
ORDER BY Collision_Frequency DESC
LIMIT 25;

-- 17. How do peak hours on various days affect collision frequencies?

SELECT 
    CASE 
        WHEN strftime('%w', collision_date) = '0' THEN 'Sunday'
        WHEN strftime('%w', collision_date) = '1' THEN 'Monday'
        WHEN strftime('%w', collision_date) = '2' THEN 'Tuesday'
        WHEN strftime('%w', collision_date) = '3' THEN 'Wednesday'
        WHEN strftime('%w', collision_date) = '4' THEN 'Thursday'
        WHEN strftime('%w', collision_date) = '5' THEN 'Friday'
        WHEN strftime('%w', collision_date) = '6' THEN 'Saturday'
    END as Day_of_Week,
    CASE 
        WHEN strftime('%H:%M', collision_time) BETWEEN '06:00' AND '09:00' OR strftime('%H:%M', collision_time) BETWEEN '16:00' AND '19:00' THEN 'Peak Hours'
        ELSE 'Off-Peak Hours'
    END as Time_of_Day,
    collision_severity,
    COUNT(*) as Total_Collisions,
    AVG(c.killed_victims + c.injured_victims) as Average_Victims,
    SUM(CASE WHEN c.alcohol_involved = 1 THEN 1 ELSE 0 END) as Alcohol_Related_Collisions,
    SUM(CASE WHEN p.cellphone_in_use = 1 THEN 1 ELSE 0 END) as Cellphone_Related_Collisions,
    AVG(p.party_age) as Average_Age_of_Driver
FROM collisions c
JOIN parties p ON c.case_id = p.case_id
GROUP BY Day_of_Week, Time_of_Day, collision_severity
ORDER BY Day_of_Week, Time_of_Day, collision_severity;

-- 18. During what hours are collisions most prevalant for different cases?

SELECT 
    strftime('%H', collision_time) as Hour,
    ROUND(SUM(CASE WHEN pedestrian_collision = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as Percent_Pedestrian_Collisions,
    ROUND(SUM(CASE WHEN bicycle_collision = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as Percent_Bicyclist_Collisions,
    ROUND(SUM(CASE WHEN motorcycle_collision = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as Percent_Motorcyclist_Collisions,
    ROUND(SUM(CASE WHEN truck_collision = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) as Percent_Truck_Collisions,
    SUM(injured_victims) as Total_Injuries,
    SUM(killed_victims) as Total_Fatalities
FROM collisions
WHERE Hour IS NOT NULL
GROUP BY Hour;

-- 19. Geospatial analysis (for Tableau)

SELECT 
    c.latitude,
    c.longitude,
    c.collision_severity,
    c.weather_1 as Weather,
    c.road_condition_1 as Road_Condition,
    c.lighting as Lighting,
    c.collision_date,
    c.collision_time,
    CASE WHEN c.alcohol_involved = 1 THEN 'Yes' ELSE 'No' END as Alcohol_Involved,
    c.type_of_collision,
    COUNT(p.id) as Total_Parties_Involved,
    SUM(c.killed_victims) as Total_Killed_Victims,
    SUM(c.injured_victims) as Total_Injured_Victims,
    SUM(CASE WHEN p.at_fault = 1 THEN 1 ELSE 0 END) as Total_At_Fault
FROM collisions c
JOIN parties p ON c.case_id = p.case_id
WHERE c.latitude IS NOT NULL AND c.longitude IS NOT NULL
GROUP BY c.case_id
ORDER BY c.collision_date, c.collision_time;

-- 20. How do different types of collisions vary annually in relation to weather and road conditions?
SELECT 
    strftime('%Y', collision_date) as Year,
    weather_1 as Weather,
    type_of_collision, 
    road_condition_1, 
    COUNT(*) as Total
FROM collisions
WHERE 
    collision_date IS NOT NULL AND
    weather_1 IS NOT NULL AND 
    type_of_collision IS NOT NULL AND 
    road_condition_1 IS NOT NULL
GROUP BY Year, Weather, type_of_collision, road_condition_1;

-- 21. Ranking of Most Dangerous Roads by Collisions

SELECT 
    primary_road,
    Total_Collisions,
    Fatalities,
    Injuries,
    DUI_Collisions,
    RANK() OVER (
        ORDER BY Total_Collisions DESC, Fatalities DESC, Injuries DESC, DUI_Collisions DESC
    ) as Danger_Rank
FROM 
    (SELECT 
         c.primary_road,
         COUNT(*) as Total_Collisions,
         SUM(c.killed_victims) as Fatalities,
         SUM(c.injured_victims) as Injuries,
         SUM(CASE WHEN p.party_sobriety = 'had been drinking, under influence' THEN 1 ELSE 0 END) as DUI_Collisions
     FROM collisions c
     JOIN parties p ON c.case_id = p.case_id
     GROUP BY c.primary_road
    ) as SubQuery
WHERE Total_Collisions > 50000
ORDER BY Total_Collisions DESC, Fatalities DESC, Injuries DESC, DUI_Collisions DESC;






