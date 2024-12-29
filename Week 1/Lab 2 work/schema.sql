-- similar to lab 1

Create TYPE scoring_class AS ENUM('star', 'good', 'bad', 'average');

CREATE TABLE players (
    player_name TEXT,
    height TEXT,
    college TEXT,
    country TEXT,
    draft_year TEXT,
    draft_round TEXT,
    draft_number TEXT,
    season_stats season_stats[],
    scoring_class scoring_class,
    years_since_last_active INTEGER,
    current_season INTEGER,
    is_active BOOLEAN,
    PRIMARY KEY (player_name, current_season)
);

CREATE TABLE players_scd(
	player_name TEXT,
	scoring_class scoring_class,
	is_active BOOLEAN,
	start_season INTEGER,
	end_season INTEGER,
    current_season INTEGER,
	PRIMARY KEY(player_name, start_season)
);

CREATE TYPE scd_type AS (
					scoring_class scoring_class,
					is_active boolean,
					start_season INTEGER,
					end_season INTEGER
)