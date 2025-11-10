-- Create a new database for your project
CREATE DATABASE golf_analysis_db;

-- Tell MySQL to use this new database
USE golf_analysis_db;

CREATE TABLE pga_tour_data (
    player_name TEXT,
    rounds NUMERIC,
    fairway_percentage NUMERIC,
    year INTEGER,
    avg_distance NUMERIC,
    gir NUMERIC,
    average_putts NUMERIC,
    average_scrambling NUMERIC,
    average_score NUMERIC,
    points TEXT, -- some values have commas
    wins NUMERIC,
    top_10 NUMERIC,
    average_sg_putts NUMERIC,
    average_sg_total NUMERIC,
    sg_ott NUMERIC,
    sg_apr NUMERIC,
    sg_arg NUMERIC,
    money TEXT
);

SELECT COUNT(*) FROM pga_tour_data;

SELECT * FROM pga_tour_data LIMIT 5;

-- Check year range and record count per year
SELECT year, COUNT(*) 
FROM pga_tour_data 
GROUP BY year 
ORDER BY year;

-- Add new numeric columns for cleaned points and money
ALTER TABLE pga_tour_data 
ADD points_clean NUMERIC,
ADD money_clean NUMERIC;

-- Update new columns: remove commas and dollar signs, then convert to numeric
UPDATE pga_tour_data 
SET points_clean = REPLACE(REPLACE(points, ',', ''), '$', ''),
    money_clean = REPLACE(REPLACE(money, ',', ''), '$', '');

-- Verify conversion worked
SELECT points, points_clean, money, money_clean 
FROM pga_tour_data 
LIMIT 5;

-- See top 10 players by earnings in latest year
SELECT player_name, year, money_clean
FROM pga_tour_data
WHERE year = 2018
ORDER BY money_clean DESC
LIMIT 10;

-- Check for missing strokes gained data
SELECT 
    COUNT(*) AS total_records,
    COUNT(average_sg_total) AS records_with_sg_data,
    COUNT(*) - COUNT(average_sg_total) AS missing_sg_data
FROM pga_tour_data;

-- See if longer hitters have lower scores
SELECT 
    year,
    AVG(avg_distance) AS avg_drive_distance,
    AVG(average_score) AS avg_scoring_avg
FROM pga_tour_data
GROUP BY year
ORDER BY year;

-- Top 10 players by Strokes Gained: Total in 2018
SELECT 
    player_name,
    average_sg_total AS sg_total,
    sg_ott,
    sg_apr, 
    sg_arg,
    average_sg_putts AS sg_putting
FROM pga_tour_data
WHERE year = 2018 AND average_sg_total IS NOT NULL
ORDER BY average_sg_total DESC
LIMIT 10;

-- Check correlation between fairway percentage and scoring average
SELECT 
    CASE 
        WHEN fairway_percentage >= 70 THEN 'Excellent (70%+)'
        WHEN fairway_percentage >= 65 THEN 'Good (65-69%)'
        WHEN fairway_percentage >= 60 THEN 'Average (60-64%)'
        ELSE 'Below Average (<60%)'
    END AS driving_accuracy,
    AVG(average_score) AS avg_score,
    COUNT(*) AS player_count
FROM pga_tour_data
WHERE year = 2018
GROUP BY driving_accuracy
ORDER BY avg_score;

-- Find players with most consistent scoring averages across years
SELECT
	player_name,
    COUNT(DISTINCT year) AS years_played,
    ROUND(AVG(average_score), 2) AS career_avg_score,
    ROUND(STDDEV(average_score), 3) AS score_std_dev -- Lower = more consistent
FROM pga_tour_data
GROUP BY player_name
HAVING COUNT(DISTINCT year) > 1  -- Only players with multiple years
ORDER BY score_std_dev ASC
LIMIT 10;

-- Top 3 earners each year
WITH ranked_earnings AS (
	SELECT
		year,
        player_name,
        money_clean,
        ROW_NUMBER() OVER (PARTITION BY year ORDER BY money_clean DESC) AS earnings_rank
	FROM pga_tour_data
    WHERE money_clean IS NOT NULL
)
SELECT year, player_name, money_clean
FROM ranked_earnings
WHERE earnings_rank <= 3
ORDER BY year DESC, earnings_rank;

-- Create a player performance profile with key metrics
SELECT 
    player_name,
    year,
    ROUND(average_score, 2) AS scoring_avg,
    ROUND(avg_distance, 1) AS drive_distance,
    ROUND(fairway_percentage, 1) AS fairway_pct,
    ROUND(gir, 1) AS greens_in_reg,
    ROUND(average_sg_total, 2) AS sg_total,
    money_clean AS earnings
FROM pga_tour_data
WHERE year = 2018 AND average_sg_total IS NOT NULL
ORDER BY sg_total DESC
LIMIT 15;

-- Which skills give the best financial return? (SG vs Earnings correlation)
SELECT 
    ROUND(AVG(money_clean), 2) AS avg_earnings,
    ROUND(AVG(average_sg_putts), 3) AS avg_sg_putting,
    ROUND(AVG(sg_ott), 3) AS avg_sg_driving,
    ROUND(AVG(sg_apr), 3) AS avg_sg_approach,
    ROUND(AVG(sg_arg), 3) AS avg_sg_short_game
FROM pga_tour_data
WHERE year = 2018 AND money_clean IS NOT NULL;

-- Find players who improved their scoring average year-over-year
WITH player_years AS(
	SELECT
		player_name,
        year,
        average_score,
        LAG(average_score) OVER (PARTITION BY player_name ORDER BY YEAR) AS prev_year_score
	FROM pga_tour_data
)
SELECT
	player_name,
    year,
    ROUND(average_score, 2) AS current_score,
    ROUND(prev_year_score, 2) AS previous_score,
    ROUND(prev_year_score - average_score, 2) AS improvement
FROM player_years
WHERE prev_year_score IS NOT NULL
ORDER BY improvement DESC
LIMIT 10;

-- How strongly do different skills correlate with earnings?
SELECT 
    'Scoring Average' AS metric,
    ROUND(
        (AVG(average_score * money_clean) - AVG(average_score) * AVG(money_clean)) / 
        (STDDEV_SAMP(average_score) * STDDEV_SAMP(money_clean)),
        3
    ) AS correlation_with_earnings
FROM pga_tour_data
WHERE year = 2018 AND money_clean IS NOT NULL

UNION ALL

SELECT 
    'Strokes Gained: Total',
    ROUND(
        (AVG(average_sg_total * money_clean) - AVG(average_sg_total) * AVG(money_clean)) / 
        (STDDEV_SAMP(average_sg_total) * STDDEV_SAMP(money_clean)),
        3
    )
FROM pga_tour_data
WHERE year = 2018 AND money_clean IS NOT NULL

UNION ALL

SELECT 
    'Driving Distance',
    ROUND(
        (AVG(avg_distance * money_clean) - AVG(avg_distance) * AVG(money_clean)) / 
        (STDDEV_SAMP(avg_distance) * STDDEV_SAMP(money_clean)),
        3
    )
FROM pga_tour_data
WHERE year = 2018 AND money_clean IS NOT NULL;


-- What does a "complete player" look like? (Top 10 by SG: Total)
SELECT 
    player_name,
    year,
    ROUND(average_score, 2) AS scoring_avg,
    ROUND(avg_distance, 1) AS drive_yds,
    ROUND(fairway_percentage, 1) AS fw_pct,
    ROUND(gir, 1) AS gir_pct,
    ROUND(average_sg_total, 3) AS sg_total,
    ROUND(money_clean, 0) AS earnings,
    -- Create performance rating
    CASE 
        WHEN average_sg_total > 1.5 THEN 'Elite'
        WHEN average_sg_total > 0.8 THEN 'All-Star' 
        WHEN average_sg_total > 0.3 THEN 'Above Average'
        ELSE 'Developing'
    END AS performance_tier
FROM pga_tour_data
WHERE year = 2018 AND average_sg_total IS NOT NULL
ORDER BY average_sg_total DESC
LIMIT 10;


-- Are long hitters less accurate? Are accurate hitters shorter?
SELECT 
    CASE 
        WHEN avg_distance >= 300 THEN 'Bomber (300+ yds)'
        WHEN avg_distance >= 290 THEN 'Long (290-299)'
        WHEN avg_distance >= 280 THEN 'Average (280-289)'
        ELSE 'Shorter (<280)'
    END AS driving_profile,
    AVG(fairway_percentage) AS avg_fairway_pct,
    AVG(average_score) AS avg_score,
    AVG(money_clean) AS avg_earnings,
    COUNT(*) AS players
FROM pga_tour_data
WHERE year = 2018
GROUP BY driving_profile
ORDER BY avg_earnings DESC;
    

-- Players showing consistent improvement across years
WITH player_trends AS (
    SELECT 
        player_name,
        COUNT(*) AS years_active,
        MIN(year) AS first_year,
        MAX(year) AS last_year,
        AVG(average_score) AS career_avg_score,
        -- Calculate improvement rate
        (MAX(average_score) - MIN(average_score)) / COUNT(*) AS score_trend
    FROM pga_tour_data
    GROUP BY player_name
    HAVING COUNT(*) >= 2  -- Multiple years of data
)
SELECT 
    player_name,
    years_active,
    ROUND(career_avg_score, 2) AS career_scoring_avg,
    ROUND(score_trend, 3) AS annual_improvement -- Negative = improving
FROM player_trends
ORDER BY score_trend ASC  -- Most improved first
LIMIT 10;
    
    
-- Export key insights for visualization:
SELECT player_name, year, average_score, avg_distance, fairway_percentage, 
       average_sg_total, money_clean, sg_ott, sg_apr, sg_arg
FROM pga_tour_data
WHERE year = 2018;

-- Multiple regression-style analysis for earnings prediction
SELECT 
    player_name,
    money_clean AS actual_earnings,
    
    -- Create predicted earnings based on key metrics
    ROUND(
        (average_sg_total * 5000000) +  -- SG Total impact
        (avg_distance * 10000) +        -- Driving distance premium  
        (fairway_percentage * 5000) +   -- Accuracy bonus
        (gir * 8000) -                  -- Greens in regulation value
        (average_putts * 300000) +      -- Putting penalty
        500000,                         -- Base earnings
        0
    ) AS predicted_earnings,
    -- Prediction accuracy | Formula: (Actual - Predicted) / Actual * 100
    ROUND(
        (money_clean - 
            ((average_sg_total * 5000000) + (avg_distance * 10000) + 
             (fairway_percentage * 5000) + (gir * 8000) - 
             (average_putts * 300000) + 500000)
        ) / money_clean * 100, 
        1
    ) AS prediction_error_pct

FROM pga_tour_data
WHERE year = 2018 AND money_clean IS NOT NULL
ORDER BY ABS(prediction_error_pct) ASC;  -- Most accurate predictions first

-- Analyze how experience (years in dataset) correlates with performance
WITH player_experience AS (
    SELECT 
        player_name,
        COUNT(DISTINCT year) AS years_active,
        MIN(year) AS first_year,
        MAX(year) AS last_year
    FROM pga_tour_data
    GROUP BY player_name
    HAVING COUNT(DISTINCT year) >= 2  -- Only players with multiple years
)
SELECT 
    pe.player_name,
    pe.years_active,
    ROUND(pd.average_score, 2) AS current_score,
    ROUND(pd.average_sg_total, 3) AS current_sg_total,
    ROUND(pd.money_clean, 0) AS current_earnings,
    
    -- Experience vs Performance analysis
    CASE 
        WHEN pe.years_active >= 4 THEN 'Veteran'
        WHEN pe.years_active = 3 THEN 'Established' 
        WHEN pe.years_active = 2 THEN 'Developing'
        ELSE 'Rookie'
    END AS experience_level

FROM player_experience pe
JOIN pga_tour_data pd ON pe.player_name = pd.player_name AND pd.year = 2018
WHERE pd.average_sg_total IS NOT NULL
ORDER BY pe.years_active DESC, pd.average_sg_total DESC;

-- Executive Dashboard: Complete player performance summary for 2018
SELECT 
    player_name,
    year,
    average_score,
    avg_distance,
    fairway_percentage,
    gir,
    average_putts,
    average_sg_total,
    sg_ott,
    sg_apr,
    sg_arg,
    average_sg_putts,
    money_clean,
    points_clean,
    wins,
    top_10,
    
    -- Performance tier classification
    CASE 
        WHEN average_sg_total > 1.5 THEN 'Superstar'
        WHEN average_sg_total > 0.8 THEN 'All-Star'
        WHEN average_sg_total > 0.3 THEN 'Above Average'
        WHEN average_sg_total > -0.3 THEN 'Average'
        ELSE 'Below Average'
    END AS performance_tier,
    
    -- Player archetype based on strengths
    CASE 
        WHEN avg_distance > 305 AND sg_ott > 0.5 THEN 'Power Hitter'
        WHEN fairway_percentage > 68 AND sg_ott > 0.3 THEN 'Accuracy Player'
        WHEN sg_apr > 0.6 THEN 'Iron Specialist'
        WHEN average_sg_putts > 0.5 THEN 'Putting Specialist'
        WHEN sg_arg > 0.4 THEN 'Short Game Wizard'
        ELSE 'Balanced Player'
    END AS player_archetype

FROM pga_tour_data
WHERE year = 2018 AND average_sg_total IS NOT NULL
ORDER BY average_sg_total DESC;

-- Top 10% vs overall average earnings
WITH player_rankings AS (
    SELECT 
        player_name,
        money_clean,
        average_sg_total,
        PERCENT_RANK() OVER (ORDER BY average_sg_total DESC) AS performance_percentile
    FROM pga_tour_data
    WHERE year = 2018 AND average_sg_total IS NOT NULL
)
SELECT 
    'Top 10% Performers' AS group_type,
    ROUND(AVG(money_clean), 0) AS avg_earnings,
    COUNT(*) AS player_count
FROM player_rankings
WHERE performance_percentile <= 0.10  -- Top 10%

UNION ALL

SELECT 
    'League Average' AS group_type,
    ROUND(AVG(money_clean), 0) AS avg_earnings,
    COUNT(*) AS player_count
FROM pga_tour_data
WHERE year = 2018 AND money_clean IS NOT NULL;
