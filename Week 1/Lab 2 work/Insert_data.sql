
INSERT INTO players 
-- get a single column of year values from 1996 to 2022
WITH years AS (
    SELECT *
    FROM generate_series(1996, 2022) AS season
),
-- get all player names and first season they played in
p AS (
    SELECT player_name, MIN(season) AS first_season 
    FROM player_seasons 
    GROUP BY player_name
),
-- get players and all the years they are eligible to play, as in their min season to until the last years value from above
players_and_seasons AS (
    SELECT * 
    FROM p
    JOIN years y 
    ON p.first_season <= y.season
),
-- get players yearly accumulated seasonal stats
windowed AS (
    SELECT 
        ps.player_name, 
        ps.season,
        ARRAY_REMOVE(
            ARRAY_AGG(
                CASE 
                    WHEN p1.season IS NOT NULL THEN 
                        CAST(ROW(p1.season, p1.gp, p1.pts, p1.reb, p1.ast) AS season_stats)
                END
            ) OVER (PARTITION BY ps.player_name ORDER BY COALESCE(p1.season, ps.season)), 
            NULL
        ) AS seasons
    FROM players_and_seasons ps
    LEFT JOIN player_seasons p1
    ON ps.player_name = p1.player_name AND ps.season = p1.season
    ORDER BY ps.player_name, ps.season
),
static AS ( 
    SELECT 
        player_name,
        MAX(height) AS height,
        MAX(college) AS college,
        MAX(country) AS country,
        MAX(draft_year) AS draft_year,
        MAX(draft_round) AS draft_round,
        MAX(draft_number) AS draft_number
    FROM player_seasons ps 
    GROUP BY player_name
)
SELECT 
    w.player_name, 
    s.height,
    s.college,
    s.country,
    s.draft_year,
    s.draft_number,
    s.draft_round,
    seasons AS season_stats,
    CASE 
        WHEN (seasons[cardinality(seasons)]).pts > 20 THEN 'star'
        WHEN (seasons[cardinality(seasons)]).pts > 15 THEN 'good'
        WHEN (seasons[cardinality(seasons)]).pts > 10 THEN 'average'
        ELSE 'bad'
    END::scoring_class AS scoring_class,
    w.season - (seasons[cardinality(seasons)]).season AS years_since_last_season,
    w.season AS current_season,
    (seasons[cardinality(seasons)]).season = w.season AS is_active
FROM windowed w 
JOIN static s
ON w.player_name = s.player_name;


-- building a Slowly Changing Dimensions(SCDs) by loading all data at once, instead of doing it incrementally
INSERT INTO players_scd
WITH with_previous as (
	SELECT 
		player_name, 
		current_season,
		scoring_class, 
		is_active,
		LAG(scoring_class,1) OVER (PARTITION BY player_name ORDER BY current_season  ) as previous_scoring_class,
		LAG(is_active,1) OVER (PARTITION BY player_name ORDER BY current_season  ) as previous_is_active
	FROM players
) ,
	with_indicators AS(
		SELECT *,
			CASE WHEN scoring_class <> previous_scoring_class THEN 1
				 WHEN is_active <> previous_is_active THEN 1
				ELSE 0 
				END as change_indicator		
		FROM with_previous
	),
	with_streaks AS (
		SELECT *, SUM(change_indicator) OVER (PARTiTION BY player_name ORDER BY current_season) AS streak_identifier 
		FROM with_indicators
	)

	SELECT player_name,
			scoring_class,
			is_active,

			MIN(current_season) as start_season,
			MAX(current_season) as end_season,
			2021 AS current_season
		FROM with_streaks
	GROUP BY player_name, streak_identifier, is_active, scoring_class
	ORDER BY player_name;


select * from players_scd

-- filling players_scd sequentially

WITH last_season_scd AS (
	SELECT * FROM players_scd
	WHERE current_season = 2021
	AND end_season = 2021
),
historical_scd AS (
	SELECT
		player_name,
		scoring_class,
		is_active,
		start_season,
		end_season
	FROM Players_scd
	WHERE current_season = 2021
	AND end_season < 2021

),
this_season_data AS (
	SELECT* FROM players
	WHERE current_season = 2022
),
unchanged_records AS (
	SELECT ts.player_name, ts.scoring_class, ts.is_active, ls.start_season, ts.current_season as end_season
		FROM this_season_data ts 
		JOIN last_season_scd ls
		ON ls.player_name = ts.player_name
		WHERE ts.scoring_class = ls.scoring_class 
		AND ts.is_active = ls.is_active
),
changed_records AS (
		SELECT 
			ts.player_name, 
			UNNEST(ARRAY[
				ROW(
					ls.scoring_class,
					ls.is_active,
					ls.start_season,
					ls.end_season

				)::scd_type,
				ROW(
					ts.scoring_class,
					ts.is_active,
					ts.current_season,
					ts.current_season

				)::scd_type
			]) as records
		FROM this_season_data ts 
		LEFT JOIN last_season_scd ls
		ON ls.player_name = ts.player_name
		WHERE ts.scoring_class <> ls.scoring_class 
		OR ts.is_active <> ls.is_active
		OR ls.player_name IS NULL
),
unnested_changed_records AS (
	SELECT player_name, 
		(records::scd_type).scoring_class,
		(records::scd_type).is_active,
		(records::scd_type).start_season,
		(records::scd_type).end_season
		FROM changed_records
),
new_records AS (
	SELECT ts.player_name, 
	ts.scoring_class, 
	ts.is_active, 
	ts.current_season AS start_season,
	ts.current_season AS end_season 
	FROM this_season_data ts
	LEFT JOIN last_season_scd ls ON 
	ts.player_name = ls.player_name
	WHERE ls.player_name IS NULL
)
SELECT * FROM historical_scd
UNION ALL

SELECT * FROM unchanged_records

UNION ALL

SELECT * FROM unnested_changed_records

UNION ALL

SELECT * FROM new_records;