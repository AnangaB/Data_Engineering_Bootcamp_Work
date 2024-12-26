
-- Insert data into the players table
-- Example of Cumulative Table Design, and can help model hows stats of players are changing over the years
-- to cumulatively build it, would need to pick an initial year, and intial year + 1, replacing the 2000 and 2001 below

	WITH yesterday AS (
		SELECT * FROM players
		WHERE current_season = 2000
	),
		today AS (
			SELECT * FROM player_seasons
			WHERE season = 2001
		)
	SELECT
		COALESCE(t.player_name,y.player_name) AS player_name,
		COALESCE(t.height,y.height) AS height,
		COALESCE(t.college,y.college) AS college,
		COALESCE(t.country,y.country) AS country,
		COALESCE(t.draft_year,y.draft_year) AS draft_year,
		COALESCE(t.draft_round,y.draft_round) AS draft_round,
		COALESCE(t.draft_number,y.draft_number) AS draft_number,
		-- is there is no season stats yesterday then just set to todays season stats, otherwise concatinate yesterdays and todays
        -- as the table builds yesterday maybe have season stats for multiple seasons
		CASE WHEN y.season_stats IS NULL
			THEN ARRAY[ROW(
				t.season,
				t.gp,
				t.pts,
				t.reb,
				t.ast
			)::season_stats]
		WHEN t.season IS NOT NULL THEN y.season_stats || 
		ARRAY[ROW(
				t.season,
				t.gp,
				t.pts,
				t.reb,
				t.ast
			)::season_stats]
		ELSE y.season_stats
		END as season_stats,			
        -- current season is equal to either todays season if available or yesterdays + 1
		COALESCE(t.season, y.current_season + 1) AS current_season,
        -- years since last season is 0 if they are playing in todays season, otherwise its yesterday seasons + 1
        CASE 
            WHEN t.season IS NOT NULL THEN 0
            ELSE y.years_since_last_season + 1
        END AS years_since_last_season,
	
        -- set scoring class
        CASE 
        WHEN t.season IS NOT NULL THEN 
            CASE 
                WHEN t.pts > 20 THEN 'star'
                WHEN t.pts > 15 THEN 'good'
                WHEN t.pts > 10 THEN 'average'
                ELSE 'bad'::scoring_class
            END
        ELSE y.scoring_class
    END AS scoring_class



	FROM today t FULL OUTER JOIN yesterday y 
		ON t.player_name = y.player_name;
	