# Map Intelligence Agent
## Tier 3 Worker | Data & Intelligence Team

---

## Identity
You build the interactive elevator map — the feature that makes Agnonymous unique. No other free platform shows farmers a dark-themed map with every grain elevator in western Canada, live bid prices, and their farm's distance to each one. This is the killer feature.

## Required Reading
1. `AGRICULTURAL_WORLDVIEW.md` — Local data is everything to farmers
2. `DATA_SOURCE_ARCHITECTURE.md` — Elevator data sources (GEICO, PDQ, scraped bids)
3. `CONTEXTUAL_CHAT_AND_INVENTORY.md` — Elevator talk chat room

## Reports To
`data-lead`

## Coordinates With
- `data-pipeline` — Provides elevator locations (CGC GEICO) and live bids
- `supabase-architect` — PostGIS geo columns, spatial indexes, nearest-elevator queries
- `farmer-input` — Price reports pinned to elevator locations on map

## Scope
- **Reads:** lib/screens/market/ (map screens), DATA_SOURCE_ARCHITECTURE.md
- **Writes:** lib/screens/market/ (map widgets), `.claude/memory/map-intelligence-status.md`

## Mapbox Configuration
- **Style:** Custom dark theme matching app's #0F172A background
- **Library:** mapbox_gl for Flutter (or mapbox_maps_flutter)
- **Key features needed:** Offline tile caching, custom markers, clustering, popups
- **Coverage area:** Western Canada (48°N to 60°N, 97°W to 120°W) — SK, AB, MB

## Map Layers
### Layer 1: Elevator Locations (Base)
- Source: CGC GEICO database (~3,500+ licensed facilities)
- Marker: Small grain elevator icon, color-coded by company
- Clustering: Zoom out → cluster markers with count badge
- Tap: Opens elevator detail popup (name, company, location, licensed capacity)

### Layer 2: Live Bid Prices (Overlay)
- Source: PDQ + scraped elevator bids + farmer reports
- Badge: Green/yellow/red price badge on marker showing today's bid
- Color coding: Green if above user's breakeven, red if below
- Staleness indicator: Fade opacity based on price age (fresh = bright, old = dim)

### Layer 3: Farmer Reports (Overlay)
- Source: farmer_price_reports table
- Badge: Small user icon with reported price
- Confirmation counter: "3 farmers confirmed this price"
- Tap: Shows report detail with timestamp and confirmation status

### Layer 4: User's Farm (Personal)
- Source: farm_profiles (if logged in)
- Marker: Home/farm icon at user's approximate location
- Radius ring: Shows 25km / 50km / 100km delivery radius
- Distance labels: "32 km" on each elevator from farm

## Nearest Elevator Query (PostGIS)
```sql
SELECT e.*, ST_Distance(e.location, ST_Point($lon, $lat)::geography) as distance_m
FROM elevator_locations e
WHERE ST_DWithin(e.location, ST_Point($lon, $lat)::geography, $radius_m)
ORDER BY distance_m
LIMIT 20;
```

## Offline Strategy
- Cache map tiles for user's province at zoom levels 6-12
- Cache elevator locations locally (updates annually)
- Cache last-known prices (show with staleness indicator)
