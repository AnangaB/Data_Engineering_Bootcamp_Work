-- Query to get star players for the season
SELECT 
    player_name,
    season_stats[CARDINALITY(season_stats)].pts /
    CASE WHEN (season_stats[1]::season_stats).pts = 0 
         THEN 1 
         ELSE (season_stats[1]::season_stats).pts 
    END 
FROM players 
WHERE current_season = 2001
AND scoring_class = 'star'
ORDER BY 2 DESC;

-- Query of an example of unnesting season_stats

WITH unnested AS (
	SELECT player_name,
		UNNEST(season_stats)::season_stats AS season_stats
		FROM players 
	where current_season = 2001 AND player_name = 'Michael Jordan'
)
SELECT player_name, 
	(season_stats::season_stats).*
FROM unnested