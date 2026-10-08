# Build franchise head-to-head records, 1954-55 through 2025-26
# (regular season, play-in, NBA Cup final, playoffs).
#
# Sources: FiveThirtyEight nbaallelo.csv (through 2014-15)
#          + sportsdataverse hoopR schedules (2015-16 on).
#
# Setup (run from the repo root; needs dplyr, readr, jsonlite, arrow):
#   data/elo.csv          <- https://github.com/fivethirtyeight/data/blob/master/nba-elo/nbaallelo.csv
#   data/hoopr/*.parquet  <- nba_schedule_2015.parquet ... nba_schedule_2026.parquet from
#                            https://github.com/sportsdataverse/hoopR-nba-data/tree/main/nba/schedules/parquet
# Outputs nba_pairs.json, nba_h2h_pairs.csv and nba_games_1955_2026.csv in the repo root.

suppressPackageStartupMessages({
  library(dplyr)
  library(readr)
  library(jsonlite)
})

hoopr_dir <- "data/hoopr"
read_pq <- function(path, cols) arrow::read_parquet(path, col_select = all_of(cols))

# ---- 538: one row per game (_iscopy == 0), NBA only, shot-clock era (season ending 1955 onward) ----
elo <- read_csv("data/elo.csv", show_col_types = FALSE) |>
  filter(`_iscopy` == 0, lg_id == "NBA", year_id >= 1955)

# Official NBA lineage: 1988-2002 Charlotte Hornets history belongs to today's Hornets, not the Pelicans
fran538 <- function(team_id, fran) if_else(team_id == "CHH", "Hornets", fran)

old <- elo |>
  transmute(
    season = year_id,
    a = fran538(team_id, fran_id),
    b = fran538(opp_id, opp_fran),
    a_win = pts > opp_pts,
    stage = if_else(is_playoffs == 1, "post", "reg"),
    pts, opp_pts
  )

# ---- hoopR (ESPN) from 2015-16 onward ----
espn <- c(
  ATL = "Hawks", BKN = "Nets", BOS = "Celtics", CHA = "Hornets", CHI = "Bulls", CLE = "Cavaliers",
  DAL = "Mavericks", DEN = "Nuggets", DET = "Pistons", GS = "Warriors", HOU = "Rockets", IND = "Pacers",
  LAC = "Clippers", LAL = "Lakers", MEM = "Grizzlies", MIA = "Heat", MIL = "Bucks", MIN = "Timberwolves",
  NO = "Pelicans", NY = "Knicks", OKC = "Thunder", ORL = "Magic", PHI = "Sixers", PHX = "Suns",
  POR = "Trailblazers", SAC = "Kings", SA = "Spurs", TOR = "Raptors", UTAH = "Jazz", WSH = "Wizards"
)

load_hoopr <- function(seasons) {
  cols <- c("game_id", "season", "season_type", "home_abbreviation", "away_abbreviation",
            "home_score", "away_score", "status_type_completed")
  d <- bind_rows(lapply(seasons, function(s) {
    read_pq(file.path(hoopr_dir, sprintf("nba_schedule_%d.parquet", s)), cols) |>
      mutate(across(c(home_score, away_score), as.integer))
  })) |>
    filter(status_type_completed,
           home_abbreviation %in% names(espn), away_abbreviation %in% names(espn),
           season_type %in% c(2, 3, 5)) |>   # 2 = regular season, 3 = playoffs, 5 = play-in (All-Star excluded)
    distinct(game_id, .keep_all = TRUE)
  stopifnot(all(d$home_score != d$away_score))
  d |>
    transmute(
      season = as.integer(season),
      a = unname(espn[home_abbreviation]),
      b = unname(espn[away_abbreviation]),
      a_win = home_score > away_score,
      stage = c(`2` = "reg", `3` = "post", `5` = "playin")[as.character(season_type)],
      pts = home_score, opp_pts = away_score
    )
}

# Put each game in alphabetical (x, y) order so both directions land in the same pair
to_pairs <- function(games) {
  games |>
    mutate(x = pmin(a, b), y = pmax(a, b), xw = if_else(a == x, a_win, !a_win))
}

# ---- cross-check: 2014-15 exists in both sources; head-to-head results should agree ----
h2h <- function(games) to_pairs(games) |> group_by(x, y) |> summarise(n = n(), xw = sum(xw), .groups = "drop")
cmp <- full_join(h2h(filter(old, season == 2015)), h2h(load_hoopr(2015)),
                 by = c("x", "y"), suffix = c("_538", "_espn"))
mism <- filter(cmp, is.na(n_538) | is.na(n_espn) | n_538 != n_espn | xw_538 != xw_espn)
cat("2014-15 cross-check: games 538 =", sum(cmp$n_538, na.rm = TRUE),
    " espn =", sum(cmp$n_espn, na.rm = TRUE), " mismatched pairs =", nrow(mism), "\n")
if (nrow(mism)) print(mism)

games <- bind_rows(old, load_hoopr(2016:2026))
cat("seasons", min(games$season), "-", max(games$season), " games", nrow(games), "\n")
print(count(games, stage))
cat(length(unique(c(games$a, games$b))), "franchises\n")

# ---- pair records ----
p <- to_pairs(games)
pairs <- p |>
  group_by(x, y) |>
  summarise(m = n(), wx = sum(xw), pm = sum(stage == "post"), pwx = sum(xw & stage == "post"),
            .groups = "drop") |>
  mutate(wy = m - wx, pwy = pm - pwx) |>
  arrange(desc(m))
cat("pairs", nrow(pairs), " meetings range", min(pairs$m), "-", max(pairs$m), "\n")

# first season (year the season ended) each franchise appears in this window
first <- bind_rows(select(games, season, t = a), select(games, season, t = b)) |>
  group_by(t) |> summarise(season = min(season), .groups = "drop")

# ---- outputs ----
out <- list(
  pairs = unname(lapply(seq_len(nrow(pairs)), function(i) with(pairs[i, ],
    list(x, y, m, wx, wy, pm, pwx, pwy)))),
  first = as.list(setNames(first$season, first$t)),
  games = nrow(games)
)
write_json(out, "nba_pairs.json", auto_unbox = TRUE)

pairs |>
  transmute(team_a = x, team_b = y, meetings = m, a_wins = wx, b_wins = wy,
            playoff_meetings = pm, a_playoff_wins = pwx, b_playoff_wins = pwy) |>
  mutate(across(c(team_a, team_b), \(t) recode(t, Sixers = "76ers", Trailblazers = "Trail Blazers"))) |>
  write_csv("nba_h2h_pairs.csv")

write_csv(games, "nba_games_1955_2026.csv")
