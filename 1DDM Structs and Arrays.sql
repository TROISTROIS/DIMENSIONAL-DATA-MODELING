SELECT * FROM player_seasons LIMIT 5;

-- temporal problem of the table
-- create a table with one row per player and has an array of all their seasons

-- 1. go through the table, what attributes are constantly changing and what are not
-- create struct

CREATE TYPE season_stats AS(
    season INTEGER,
    gp INTEGER,
    pts REAL,
    reb REAL,
    ast REAL
                        );

-- DROP TYPE season_stats;

-- scoring class
CREATE TYPE scoring_class AS ENUM ('star','good','average','bad');

--  create a table with all columns and array of seasons stats
CREATE TABLE players(
    player_name TEXT,
    height TEXT,
    college TEXT,
    country TEXT,
    draft_year TEXT,
    draft_round TEXT,
    draft_number TEXT,
    season_stats season_stats[],
    scoring_class scoring_class,
    years_since_last_season INTEGER,
    current_season INTEGER,
    PRIMARY KEY(player_name, current_season)
);

-- DROP TABLE players;
-- 2. full outer logic
-- what is the first year?
SELECT MIN(season) FROM player_seasons;

-- today and yesterday query
WITH yesterday AS (
    SELECT * FROM players
             WHERE current_season = 1995
),
    today AS (
        SELECT * FROM player_seasons
                 WHERE season = 1996
    )

SELECT * FROM today t FULL OUTER JOIN yesterday y
ON t.player_name = y.player_name;

-- coalesce the values that are not temporal
-- seed query for cumulating
-- turn it into a pipeline

INSERT INTO players
WITH yesterday AS (
    SELECT * FROM players
             WHERE current_season = 2000
),
    today AS (
        SELECT * FROM player_seasons
                 WHERE season = 2001

    )

SELECT
    COALESCE(t.player_name, y.player_name) AS player_name,
    COALESCE(t.height, y.height) AS height,
    COALESCE(t.college, y.college) AS college,
    COALESCE(t.country, y.country) AS country,
    COALESCE(t.draft_year, y.draft_year) AS draft_year,
    COALESCE(t.draft_round, y.draft_round) AS draft_round,
    COALESCE(t.draft_number, y.draft_number) AS draft_number,

-- if null, create initial array with 1 value
    CASE WHEN y.season_stats IS NULL
        THEN ARRAY[ROW(
            t.season,
            t.gp,
            t.pts,
            t.reb,
            t.ast
            )::season_stats]
-- if today is not null, create null value
    WHEN t.season IS NOT NULL THEN y.season_stats || ARRAY[ROW(
            t.season,
            t.gp,
            t.pts,
            t.reb,
            t.ast
            )::season_stats]
-- carry history forward to avoid adding nulls as in retired players,...
    ELSE y.season_stats

    END AS season_stats,

    CASE
        WHEN t.season IS NOT NULL THEN
        CASE WHEN t.pts > 20 THEN 'star'
            WHEN t.pts > 15 THEN 'good'
            WHEN t.pts > 10 THEN 'average'
            ELSE 'bad'
        END::scoring_class
        ELSE y.scoring_class
    END,
    CASE
        WHEN t.season IS NOT NULL THEN 0
        ELSE y.years_since_last_season + 1
            END AS years_since_last_season,
--     current season value
    COALESCE(t.season, y.current_season +1) AS current_season
FROM today t FULL OUTER JOIN yesterday y
ON t.player_name = y.player_name;

-- 2001
SELECT * FROM players WHERE current_season=2001;

-- Michael Jordan
-- Did not play in 1998,1999,2001
-- flattened table
SELECT * FROM players WHERE current_season = 2001
AND player_name = 'Michael Jordan';

-- exploded table
WITH unnested AS (SELECT player_name,
                         UNNEST(season_stats)::season_stats AS season_stats
                  FROM players
                  WHERE current_season = 2001
--                     AND player_name = 'Michael Jordan'
                    )
SELECT player_name,
       (season_stats::season_stats).*
FROM unnested;


-- analytics
-- most improved from last season to current season
SELECT player_name,
        (season_stats[CARDINALITY(season_stats)]::season_stats).pts/
      CASE WHEN (season_stats[1]::season_stats).pts = 0 THEN 1
            ELSE (season_stats[1]::season_stats).pts
END AS improvement
       FROM players
WHERE current_season = 2001
ORDER BY 2 DESC;


