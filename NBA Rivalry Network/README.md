# NBA Rivalry Network

An interactive chord diagram of head-to-head records among all 30 NBA franchises, from the start of the shot clock era (1954–55) through 2025–26. Toggle between all games and playoffs only, and click any team to see its record against every opponent.

**Live page:** _add your GitHub Pages or Netlify link here_

## How to read it

- **Line thickness:** number of meetings
- **Line shade:** faint is close to even, bold is one-sided
- **Line color:** the team with the better record
- **Bubble size:** total games played by that franchise

## Data

- [FiveThirtyEight NBA Elo game log](https://github.com/fivethirtyeight/data/tree/master/nba-elo) (CC BY 4.0), 1954–55 to 2014–15
- [sportsdataverse hoopR NBA data](https://github.com/sportsdataverse/hoopR-nba-data) (ESPN schedules), 2015–16 to 2025–26

The two sources overlap in 2014–15 and agree on every game that season.

Includes regular season, play-in, NBA Cup final and playoff games; ABA games are excluded. Records follow franchises, not cities (the Thunder include Seattle, the Kings include Rochester, Cincinnati and Kansas City), and the 1988–2002 Charlotte Hornets seasons belong to today's Hornets, following the NBA's official lineage.

## Files

| File | What it is |
|---|---|
| `index.html` | The full interactive page, with the data embedded |
| `build_nba.R` | Rebuilds the head-to-head records from the raw game data |
| `nba_h2h_pairs.csv` | Records for all 435 franchise pairs |

To rebuild the data, download the sources listed at the top of `build_nba.R` into `data/` and run it from the repo root.

---

By Dillon Murphy
