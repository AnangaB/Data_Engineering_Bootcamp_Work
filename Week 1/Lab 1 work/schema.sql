-- Create the scoring_class ENUM type
CREATE TYPE scoring_class AS ENUM('star', 'good', 'bad', 'average');

-- Create the players table
CREATE TABLE players (
    player_name TEXT,
    height TEXT,
    college TEXT,
    country TEXT,
    draft_year TEXT,
    draft_round TEXT,
    draft_number TEXT,
    season_stats season_stats[],
    current_season INTEGER,
    years_since_last_season INTEGER,
    scoring_class scoring_class,
    PRIMARY KEY(player_name, current_season)
);