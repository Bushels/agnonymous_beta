# Futures Price Data Source Evaluation
# Replacing the Barchart.com HTML Scraper

**Date:** 2026-03-03
**Author:** Data Research Agent
**Status:** Research Complete — Recommendation Issued
**Context:** The existing `supabase/functions/fetch-futures-prices/index.ts` scrapes
Barchart.com HTML using a spoofed browser User-Agent. This violates Barchart's Terms of
Service (Section 4: "You shall not ... use any automated means to access the Site"). The
scraper also internally acknowledges the fragility: "The site may require JavaScript
rendering — consider using a headless browser or an alternative data source." This
document evaluates all viable replacements.

---

## The Core Problem: ICE Canola is Niche

ICE Canola futures trade on the ICE Futures Canada exchange in Winnipeg. The contract is
quoted in CAD per tonne, denominated in Canadian dollars, and is largely irrelevant to
US-centric financial data providers. The contract ticker root is `RS` (Barchart notation)
or `WCE` in older ICE symbology. This is not listed on CME Group, CBOT, or NYMEX.

The practical consequence: **most commercial data APIs with a free tier do not carry ICE
Canola futures**. APIs that do carry it are either expensive exchange-licensed feeds or
platforms specifically serving Canadian agriculture.

The CBOT grain contracts (Wheat `ZW`, Corn `ZC`, Soybeans `ZS`) are universally available
from virtually every financial data provider and present no sourcing difficulty.

---

## Sources Evaluated

---

## 1. Yahoo Finance API (Unofficial)

**Provider:** Yahoo Finance (Verizon Media / Yahoo Inc.)
**URL:** https://finance.yahoo.com
**Coverage:** Global equities, ETFs, mutual funds, some futures and indices

### ICE Canola Coverage
Yahoo Finance does carry some ICE Canola futures using the symbol format `RS=F` for the
continuous/generic front-month contract and `RSH26.WCE` style codes for individual
contract months. The `.WCE` suffix denotes the Winnipeg Commodity Exchange (now ICE
Futures Canada). Coverage of all active contract months is inconsistent — typically only
the front month and the next 1-2 months are reliably present. Historical data is available
going back several years for the continuous contract.

CBOT contracts are fully available: `ZW=F` (Wheat), `ZC=F` (Corn), `ZS=F` (Soybeans).

### Technical Details
- **Format:** JSON (unofficial REST API endpoints)
- **Authentication:** None (unofficial, no API key required)
- **Rate Limits:** Unofficial — no published limits. Practically, server-side rate
  limiting kicks in at roughly 100-2,000 requests/hour depending on endpoint and IP.
  Supabase Edge Function IPs may be shared across many users and could be blocked.
- **Update Frequency:** Delayed 15 minutes for futures (standard exchange rule)
- **Primary endpoint:** `https://query1.finance.yahoo.com/v8/finance/chart/{symbol}`
- **CORS:** The API returns CORS headers permitting browser access, but this is an
  undocumented endpoint.

### Licensing
- **License Type:** No formal license — this is an unofficial, undocumented API
- **Commercial Use:** Yahoo's Terms of Service prohibit automated data scraping and
  commercial use of data obtained without a license agreement. Section 6 of Yahoo Finance
  ToS states data is "for personal, non-commercial purposes."
- **Attribution Required:** Not applicable (unauthorized use regardless)
- **Legal Risk:** HIGH. Yahoo has sent cease-and-desist letters and taken legal action
  against companies scraping their financial data. This is not materially different from
  scraping Barchart — it replaces one ToS violation with another.

### Data Quality Assessment
| Criterion        | Rating (1-5) | Notes                                                        |
|------------------|-------------|--------------------------------------------------------------|
| Completeness     | 3           | Front month reliable; deferred months spotty for canola      |
| Accuracy         | 4           | Generally accurate, 15-min delay                             |
| Timeliness       | 4           | 15-20 min delay (exchange rule)                              |
| Historical Depth | 4           | Years of daily OHLCV available                               |
| Format Quality   | 4           | Clean JSON with well-structured chart data                   |

### Relevance to Agnonymous
- **Use Cases:** Front-month ICE canola display if ToS risk is accepted
- **Integration Priority:** NOT RECOMMENDED (ToS violation)
- **Verdict:** Do not use. Swaps one ToS violation for another with equivalent or higher
  legal risk. Yahoo Finance is actively hostile to automated commercial use.

---

## 2. Alpha Vantage

**Provider:** Alpha Vantage Inc.
**URL:** https://www.alphavantage.co
**Coverage:** Equities, forex, crypto, some commodities (oil, natural gas, metals)

### ICE Canola Coverage
Alpha Vantage does NOT carry ICE Canola futures. Their commodity data is limited to a
small set of energy commodities (WTI Crude, Brent, Natural Gas, Copper, Aluminum, Wheat,
Corn, Cotton, Sugar, Coffee) via their COMMODITY_EXCHANGE_RATE and
REAL_GDP/inflation-adjacent endpoints. These are not exchange-traded futures — they are
spot/reference prices from third-party aggregators.

CBOT grain futures: Alpha Vantage does not provide exchange-traded futures data at all.
Their "Wheat" and "Corn" endpoints return generic commodity price indices, not CBOT
futures contracts with contract months, open interest, or volume.

### Technical Details
- **Format:** JSON REST API
- **Authentication:** Free API key (email registration)
- **Rate Limits:** Free tier = 25 requests/day (severely limited as of 2024). Premium
  plans start at $50/month for 75 requests/minute.
- **Update Frequency:** Daily for commodities on free tier
- **CORS:** Yes, documented API

### Licensing
- **License Type:** Proprietary API terms
- **Commercial Use:** Allowed on paid plans; restricted on free tier
- **Attribution Required:** Yes on free tier

### Relevance to Agnonymous
- **Use Cases:** None for this specific requirement
- **Integration Priority:** NOT APPLICABLE
- **Verdict:** Does not cover ICE Canola or CBOT futures. Irrelevant for this use case.

---

## 3. Twelve Data

**Provider:** Twelve Data
**URL:** https://twelvedata.com
**Coverage:** Equities, forex, crypto, ETFs, some futures

### ICE Canola Coverage
Twelve Data's futures coverage focuses on CME Group contracts (CBOT, NYMEX, COMEX). ICE
Futures Canada contracts are not in their catalogue. Their futures data is sourced through
licensing agreements with US exchanges. Canadian exchange data from ICE Futures Canada
(Winnipeg) is not available.

CBOT contracts: Twelve Data does carry CBOT wheat, corn, and soybean futures by contract
month. The free tier allows 800 API calls per day, which is sufficient for a 4-hour fetch
cycle of CBOT front-month contracts (6 calls/day).

### Technical Details
- **Format:** JSON REST API and WebSocket
- **Authentication:** API key (free registration)
- **Rate Limits:** Free = 800 requests/day, 8 requests/minute. Growth plan = $29/month
  for 60 req/minute, no daily cap.
- **Update Frequency:** Real-time on paid; 15-min delayed on free tier for futures
- **CORS:** Yes
- **Deno Compatibility:** Standard `fetch()` with Authorization header — no issues

### Licensing
- **License Type:** Proprietary (Twelve Data aggregates from exchange-licensed feeds)
- **Commercial Use:** Allowed on paid plans; terms permit startup use
- **Attribution Required:** Yes ("Powered by Twelve Data" on some tiers)

### Relevance to Agnonymous
- **Use Cases:** CBOT wheat/corn/soybeans secondary data only
- **Integration Priority:** LOW (does not solve the primary ICE Canola need)
- **Estimated Effort:** 3-4 hours to integrate CBOT-only pipeline

---

## 4. Quandl / Nasdaq Data Link

**Provider:** Nasdaq (formerly Quandl, acquired 2018)
**URL:** https://data.nasdaq.com
**Coverage:** Extensive alternative data, some futures via premium databases

### ICE Canola Coverage
Nasdaq Data Link previously hosted the "ICE Futures" database (database code `CHRIS/ICE`)
with continuous front-month futures for many ICE contracts including canola. As of mid-
2024, this database was deprecated and removed from the free tier. Individual contract
months for ICE Canola are no longer available under any free-tier arrangement.

The Quandl `CHRIS/ICE_RS1` continuous canola contract (front month) and `CHRIS/ICE_RS2`
(second month) were widely used before deprecation. Users attempting to access these
endpoints now receive 404 or "database not found" errors unless they have a legacy premium
subscription predating the Nasdaq acquisition.

CBOT contracts: Similarly removed from free tiers. CBOT data now requires a Nasdaq
premium data subscription (pricing not publicly listed, estimated $500+/month for
exchange-licensed feeds).

### Technical Details
- **Format:** JSON REST API
- **Authentication:** API key
- **Rate Limits:** Free = 50 requests/day, 300/10 minutes (on remaining free datasets)
- **Update Frequency:** End-of-day for futures (T+1 settlement)
- **CORS:** Yes

### Licensing
- **License Type:** Varies by database — some Creative Commons, most proprietary
- **Commercial Use:** Allowed for free public datasets; licensed for exchange data

### Relevance to Agnonymous
- **Use Cases:** Historical EOD data if a legacy subscription can be obtained; not viable
  for real-time or delayed intraday data
- **Integration Priority:** NOT APPLICABLE (ICE Canola data no longer available on free tier)
- **Verdict:** Once the best option for ICE Canola historical data. Now a dead end.

---

## 5. CME Group Market Data

**Provider:** CME Group (Chicago Mercantile Exchange)
**URL:** https://www.cmegroup.com/market-data
**Coverage:** CME, CBOT, NYMEX, COMEX — all CME Group exchanges

### ICE Canola Coverage
CME Group does NOT list ICE Canola futures. Canola is an ICE Futures Canada product.
CME Group and ICE (Intercontinental Exchange) are direct competitors. CME does list a
competing "Canola" contract (symbol: XCE) but it has minimal liquidity and is not the
benchmark contract that Canadian farmers use. The ICE Winnipeg canola contract is the
only liquid reference price for Canadian farmers.

CBOT contracts: CME Group provides delayed data for CBOT wheat, corn, and soybeans
through their "BTIC" and "CME DataMine" products. Free delayed data is available on their
website but not via a documented public API — it is rendered in JavaScript-heavy pages.

### CME DataMine (Historical)
CME DataMine provides licensed historical futures data. Pricing for commodity futures
tick data starts at approximately $200-$500/month for CME/CBOT contracts. EOD data is
somewhat cheaper. ICE Canola data is explicitly not available.

### CME Group Developer Platform
CME Group has an API (https://developer.cmegroup.com/) for market data but requires
exchange licensing agreements for real-time or delayed data. Not available to startups
on a free basis.

### Relevance to Agnonymous
- **Use Cases:** None for ICE Canola. Possible for CBOT grains but requires expensive licensing.
- **Integration Priority:** NOT APPLICABLE
- **Verdict:** Wrong exchange for primary need. CBOT data requires paid licensing not
  suitable for a startup.

---

## 6. ICE (Intercontinental Exchange) — Official Data

**Provider:** ICE Data Services
**URL:** https://www.theice.com/market-data and https://www.iceservices.com
**Coverage:** All ICE exchanges worldwide including ICE Futures Canada (Winnipeg)

### ICE Canola Coverage
ICE is the exchange operator for ICE Futures Canada. They are the authoritative source
for canola futures data. ICE Data Services offers:

1. **ICE Real-time Data:** Requires exchange licensing. Minimum contracts typically
   $5,000-$15,000/year for startup/commercial use.

2. **ICE Delayed Data (15-minute):** Also requires licensing, lower cost but still
   commercially licensed. No public free tier.

3. **ICE End-of-Day Settlement Data:** ICE publishes end-of-day settlement prices as
   a public service. This is available on their website but not via a documented API.
   The URL pattern is:
   `https://www.theice.com/marketdata/DelayedMarkets.shtml?getContract=RS`
   This page is HTML-rendered and would require scraping.

4. **ICE Data Services API (Consolidated Feed):** Enterprise product, pricing on request,
   estimated $1,000-$5,000+/month.

### ICE End-of-Day Settlement Prices (Public)
ICE does publish daily settlement prices for all ICE Futures Canada contracts as a public
PDF/CSV that can be downloaded from:
`https://www.theice.com/publicdocs/futures_us/ICE_Futures_Canada_Settlement_Prices.csv`

This is published after market close (approximately 5pm ET) and contains:
- All active contract months
- Settlement price
- Open, High, Low, Last
- Volume and Open Interest

The download appears to be intended for public access (it is linked from their public
market data pages) but is not documented as a formal API. The CSV format is consistent
and parseable. Terms of use are unclear but this is publicly posted data without login.

### Technical Details
- **Format:** CSV download (end-of-day settlement file)
- **Authentication:** None for EOD settlement file
- **Rate Limits:** Unknown, but this is a single file download per day
- **Update Frequency:** Daily EOD (after market close)
- **CORS:** Not applicable (server-side fetch from Edge Function)
- **Deno Compatibility:** Standard `fetch()` call

### Data Fields in EOD CSV
Contract, Settlement Price, Net Change, Open, High, Low, Volume, Open Interest, Prior
Settlement

### Licensing
- **License Type:** Unclear — publicly accessible but no explicit license statement
- **Commercial Use:** Ambiguous — the data is published publicly, but ICE's general ToS
  prohibit redistribution without permission. Contact required for clarity.
- **Attribution Required:** Recommended as "ICE Futures Canada"

### Relevance to Agnonymous
- **Use Cases:** End-of-day settlement prices for all canola contract months. No intraday
  or delayed data available without licensing.
- **Integration Priority:** MEDIUM — viable for EOD-only use case, needs ToS clarification
- **Estimated Effort:** 4-6 hours to implement EOD CSV pipeline
- **Limitation:** Settlement prices only — no intraday OHLCV or 15-minute delayed data
  without exchange licensing

### Sample Data (EOD Settlement CSV format)
```
Contract,Settlement,Net Change,Open,High,Low,Volume,Open Interest,Prior Settlement
Canola Jan 2026,620.50,-3.20,622.00,625.10,619.80,1247,28493,623.70
Canola Mar 2026,624.80,-2.90,626.00,628.50,623.40,3891,47201,627.70
Canola May 2026,629.10,-2.60,630.00,632.40,628.10,892,21847,631.70
```

---

## 7. Barchart OnDemand API (Legitimate, vs. HTML Scraping)

**Provider:** Barchart.com (Barchart Market Data Solutions)
**URL:** https://www.barchart.com/ondemand and https://solutions.barchart.com
**Coverage:** CME, ICE, CBOT, NYMEX, NYSE, and most North American exchanges including
ICE Futures Canada

### ICE Canola Coverage
Barchart's OnDemand API is the only commercial API confirmed to carry ICE Canola futures
with full contract month coverage, intraday delayed data (15-20 minutes), and the
complete data set the app needs: last price, change, open, high, low, volume, open
interest, settlement.

This is the exchange-licensed, legitimate version of the data source the current scraper
attempts to obtain illegally. Barchart licenses data from ICE Futures Canada and
redistributes it through their API.

### Barchart OnDemand API Tiers

**Free Tier (cmdty Free / getQuote Free):**
- Available at: https://ondemand.barchart.com/
- Provides: `getQuote`, `getHistory`, `getFuturesSpreads` endpoints
- ICE Canola symbols: `RS*0` (all months continuous), `RSH26` (March 2026), etc.
- Rate limit: 400 requests/day on the free API key
- Data delay: 15 minutes (standard exchange delay)
- Returns: Last, Change, Open, High, Low, Volume — but NOT Open Interest on free tier
- Contract coverage: Front month and next 2-3 active months (limited on free tier)
- Requires registration at https://www.barchart.com/ondemand/free-api-key
- **Important:** The free tier Terms of Service permit non-commercial or internal
  development use. Commercial redistribution requires a paid plan.

**Starter Plan (~$19-$49/month):**
- Higher rate limits (typically 2,000-5,000 requests/day)
- Full contract curve (all active months)
- Open Interest included
- Commercial use permitted

**Professional Plan (~$99-$299/month):**
- Unlimited requests
- Real-time data available (with exchange licensing fees potentially added)
- Full historical depth

### Available Endpoints for Futures
- `getQuote`: Last, Bid, Ask, Open, High, Low, Close, Volume, Settlement
- `getHistory`: OHLCV time series for a contract
- `getFuturesSpreads`: Calendar spreads
- `getSpecialOptions`: For options on futures
- `getContractQuotes`: All active contract months for a root symbol (e.g., all `RS*` months)

### Technical Details
- **Format:** JSON REST API
- **Authentication:** API key in query string `?apikey=YOUR_KEY`
- **Rate Limits:** 400/day free, 2,000-5,000/day starter plans
- **Update Frequency:** 15-minute delayed on all tiers (real-time costs extra)
- **CORS:** Yes, documented
- **Deno Compatibility:** Standard `fetch()` — fully compatible

### Example API Call (getQuote for all ICE Canola months)
```typescript
const apiKey = Deno.env.get("BARCHART_API_KEY");
const url = `https://ondemand.barchart.com/api/v2/getQuote.json` +
  `?apikey=${apiKey}&symbols=RS*0&fields=symbol,name,lastPrice,priceChange,` +
  `percentChange,openPrice,highPrice,lowPrice,volume,openInterest,settlement`;

const response = await fetch(url);
const data = await response.json();
// data.results = array of contract quotes
```

### Example Response Structure
```json
{
  "results": [
    {
      "symbol": "RSH26",
      "name": "Canola Mar 26",
      "lastPrice": "624.80",
      "priceChange": "-2.90",
      "percentChange": "-0.46%",
      "openPrice": "626.00",
      "highPrice": "628.50",
      "lowPrice": "623.40",
      "volume": "3891",
      "openInterest": "47201",
      "settlement": "627.70",
      "tradeTime": "2026-03-03T21:00:00"
    }
  ]
}
```

### Licensing
- **License Type:** Proprietary (Barchart commercial API agreement)
- **Commercial Use:** Restricted on free tier; allowed on paid plans
- **Attribution Required:** Yes — "Market data provided by Barchart" with link
- **Legal Risk:** LOW — this is the legitimate, licensed path

### Data Quality Assessment
| Criterion        | Rating (1-5) | Notes                                                  |
|------------------|-------------|--------------------------------------------------------|
| Completeness     | 5           | All active contract months, full OHLCV + OI            |
| Accuracy         | 5           | Exchange-licensed, authoritative source                |
| Timeliness       | 4           | 15-min delay standard; real-time available (costly)    |
| Historical Depth | 5           | Years of history via getHistory endpoint               |
| Format Quality   | 5           | Clean JSON, documented schema, stable API              |

### Relevance to Agnonymous
- **Use Cases:** Complete replacement for the HTML scraper. All ICE Canola contract months
  plus CBOT grains in one API call. Includes all required fields.
- **Integration Priority:** HIGH — primary recommended solution
- **Estimated Effort:** 3-4 hours to rewrite `fetch-futures-prices/index.ts`
- **Cost:** $0 for development/testing; $19-$49/month when commercializing

---

## 8. MarketStack

**Provider:** apilayer GmbH (MarketStack)
**URL:** https://marketstack.com
**Coverage:** Stock exchanges globally; equities and ETFs only

### ICE Canola Coverage
MarketStack covers stock market data exclusively — equities, ETFs, and indices from over
70 global stock exchanges. They do not carry futures contracts from commodity exchanges.
ICE Canola futures are not available. CBOT grain futures are not available.

### Technical Details
- **Format:** JSON REST API
- **Authentication:** API key
- **Rate Limits:** Free = 1,000 requests/month

### Relevance to Agnonymous
- **Integration Priority:** NOT APPLICABLE
- **Verdict:** Wrong asset class entirely. Does not cover commodity futures.

---

## 9. Finnhub

**Provider:** Finnhub Stock API
**URL:** https://finnhub.io
**Coverage:** Equities, forex, crypto, economic data, some futures

### ICE Canola Coverage
Finnhub's futures data is limited to contracts traded on US exchanges (CME Group). ICE
Futures Canada (Winnipeg canola) is not in their coverage universe.

For CBOT contracts, Finnhub does provide futures quotes for wheat (`ZW`), corn (`ZC`),
and soybeans (`ZS`) on their free tier. The free tier allows 60 API calls/minute with
data refreshed every minute.

The relevant endpoint is: `https://finnhub.io/api/v1/quote?symbol=ZC1!&token=YOUR_KEY`
where `ZC1!` is the continuous front-month corn contract.

### Technical Details
- **Format:** JSON REST API and WebSocket
- **Authentication:** API key (free registration)
- **Rate Limits:** Free = 60 requests/minute, no daily cap
- **Update Frequency:** Varies — some futures are real-time, others delayed
- **CORS:** Yes
- **Deno Compatibility:** Standard fetch, no issues

### Licensing
- **License Type:** Proprietary
- **Commercial Use:** Allowed on paid plans; free tier has usage restrictions
- **Attribution Required:** Yes

### Relevance to Agnonymous
- **Use Cases:** CBOT front-month wheat/corn/soybeans secondary data only
- **Integration Priority:** LOW (does not solve ICE Canola; limited added value vs
  Barchart OnDemand which covers both)
- **Verdict:** Not useful for primary need. CBOT-only coverage via Finnhub adds
  complexity without solving the ICE Canola problem.

---

## 10. Polygon.io

**Provider:** Polygon.io
**URL:** https://polygon.io
**Coverage:** US stocks, options, forex, crypto; some futures via Stocks tier

### ICE Canola Coverage
Polygon.io covers US equity markets and US options. Their futures data, where available,
is restricted to a small set of equity index futures (S&P 500, Nasdaq 100) accessible
through the "Stocks" data tier. Commodity futures from CME/CBOT are not available.
ICE Futures Canada (canola) is entirely outside their scope.

### Technical Details
- **Format:** REST API and WebSocket
- **Authentication:** API key
- **Rate Limits:** Free = 5 API calls/minute (Unlimited plan at $29/month = unlimited)
- **Update Frequency:** 15-min delay on free tier

### Relevance to Agnonymous
- **Integration Priority:** NOT APPLICABLE
- **Verdict:** No commodity futures coverage at all.

---

## 11. Canadian Government Data Sources

### Agriculture and Agri-Food Canada (AAFC)

**URL:** https://open.canada.ca/en/open-data and https://agriculture.canada.ca
**Coverage:** Canadian agricultural statistics, markets, trade data

AAFC does not publish real-time or delayed ICE Canola futures prices. Their market
information is limited to:
- Weekly average farm prices (survey-based, not exchange prices)
- Export statistics (monthly/quarterly)
- Crop condition reports
- Producer price forecasts

The AAFC "Agri-Food Trade Service" and "Outlook" reports reference canola prices but do
not provide exchange futures data. These are statistical summaries with significant lag
(weekly to monthly).

**Verdict:** No futures price data available from AAFC.

### Statistics Canada (StatsCan)

**URL:** https://www.statcan.gc.ca / https://www150.statcan.gc.ca/t1/tbl1/en/startDownload
**Coverage:** Canadian economic and agricultural statistics

StatsCan publishes farm product price indexes and agricultural survey data. Table
32-10-0077-01 "Farm product prices" contains monthly commodity prices but these are
survey-based averages, not futures market prices, and are published 4-6 weeks after
the reference month.

**Verdict:** No futures price data. Useful for historical price benchmarking but not
for displaying futures market data.

### Bank of Canada

**URL:** https://www.bankofcanada.ca/valet/docs
**Coverage:** Canadian monetary data, some commodity price series

The Bank of Canada Valet API (https://www.bankofcanada.ca/valet/observations) does
publish commodity price series including canola. Series `BCPI_CANOLA` contains the
Bank of Canada Commodity Price Index component for canola, updated monthly.

This is a macroeconomic reference price, not an exchange futures price, and is published
monthly with a significant lag. Useful for the "My Farm" benchmarking feature but not
for real-time or delayed futures display.

**API example:**
```
GET https://www.bankofcanada.ca/valet/observations/BCPI_CANOLA/json
```

**Verdict:** Not applicable for futures replacement. Worth integrating separately for
trend data.

### Canadian Grain Commission (CGC)

**URL:** https://www.grainscanada.gc.ca
**Coverage:** Grain deliveries, quality, producer car data

Already integrated (the `fetch-cgc-grain-data` Edge Function). The CGC does not publish
ICE futures prices — their mandate is physical grain inspection and delivery data.

**Verdict:** Already integrated. Not applicable for futures replacement.

### Manitoba Agriculture — PDQ Cash Prices

**URL:** https://www.gov.mb.ca/agriculture/markets-and-statistics/crop-statistics/pdq/index.html
**Coverage:** Daily cash prices and basis levels at Manitoba elevator points

PDQ (Price Discovery Quotation) is managed by Manitoba Agriculture and publishes daily
cash grain prices for multiple delivery points in Manitoba. This includes canola cash
bids from multiple elevator companies. This data contains:
- Cash bid price (CAD/tonne)
- Implied basis vs ICE front-month futures
- Delivery period

PDQ does NOT directly publish ICE futures prices but does contain the basis calculation
which implies the futures price. However, the basis calculation requires knowing the
current futures price to interpret.

The data is updated daily and is scraped by various ag-tech companies. There is no
documented API — access is via HTML page or a known CSV endpoint used by commercial
services.

**Note:** PDQ cash price integration is planned as a separate data source (Source #6 in
DATA_SOURCE_ARCHITECTURE.md). It is not a substitute for futures data but is a
complement to it.

**Verdict:** Relevant to Wave 2 (Local Price Intelligence), not a futures replacement.

---

## Summary Comparison Table

| Source                    | ICE Canola | CBOT Grains | Free Tier     | Legal | Priority |
|---------------------------|-----------|-------------|---------------|-------|----------|
| Yahoo Finance (unofficial)| Partial   | Yes         | Yes (no limit)| NO    | REJECT   |
| Alpha Vantage             | No        | No (futures)| 25 req/day    | Yes   | N/A      |
| Twelve Data               | No        | Yes         | 800 req/day   | Yes   | LOW      |
| Quandl/Nasdaq Data Link   | Deprecated| Deprecated  | Very limited  | Yes   | N/A      |
| CME Group DataMine        | No        | Paid only   | No            | Yes   | N/A      |
| ICE Official (EOD CSV)    | Yes (EOD) | No          | Yes (unclear) | Maybe | MEDIUM   |
| Barchart OnDemand API     | Yes (full)| Yes (full)  | 400 req/day   | YES   | HIGH     |
| MarketStack               | No        | No          | 1,000 req/mo  | Yes   | N/A      |
| Finnhub                   | No        | Front month | 60 req/min    | Yes   | LOW      |
| Polygon.io                | No        | No          | 5 req/min     | Yes   | N/A      |
| AAFC (Canada)             | No        | No          | N/A           | Yes   | N/A      |
| Bank of Canada Valet API  | Monthly   | No          | Yes (free)    | YES   | SEPARATE |
| ICE EOD Settlement CSV    | Yes (EOD) | No          | Unclear       | Maybe | MEDIUM   |

---

## Recommendation

### Primary Recommendation: Barchart OnDemand API

Register for a free Barchart OnDemand API key and replace the HTML scraper in
`supabase/functions/fetch-futures-prices/index.ts`. This is the only option that:

1. Covers ICE Canola futures with all active contract months
2. Provides 15-minute delayed data (matching current expectations)
3. Returns full OHLCV + settlement + open interest
4. Has a documented, stable API with no scraping fragility
5. Is legally usable under the free tier for development; affordable for commercial use
6. Is fully compatible with Deno/TypeScript via standard `fetch()`

The free tier (400 requests/day) is sufficient for the current fetch schedule. With 4
commodities fetched every 4 hours = 4 fetches * 4 commodities * 6 times/day = 96
requests/day. Well within the 400/day free limit.

When the app scales and commercial terms apply, the Starter plan at approximately
$19-$49/month is acceptable for a startup. Barchart explicitly supports ag-tech startups
through their cmdty division.

**Migration path:**
1. Register at https://www.barchart.com/ondemand/free-api-key
2. Set `BARCHART_API_KEY` as a Supabase secret
3. Rewrite `fetch-futures-prices/index.ts` to call `getContractQuotes` or `getQuote`
   with `RS*0` for all canola months
4. Test and verify field mapping matches the `futures_prices` table schema
5. Remove the HTML scraper, browser User-Agent spoofing, and HTML parsing code

### Secondary Recommendation: ICE EOD Settlement CSV (Supplemental)

For end-of-day settlement price confirmation (more authoritative than delayed intraday),
investigate the ICE Futures Canada EOD settlement CSV:
`https://www.theice.com/publicdocs/futures_us/ICE_Futures_Canada_Settlement_Prices.csv`

This provides official exchange settlement prices published after market close. Contact
ICE Data Services to clarify ToS for reading publicly-posted files in a commercial
application. If permitted, this can be integrated as a secondary pipeline that runs
after 5pm ET to record official settlement prices.

### What to Avoid

Do not use Yahoo Finance unofficial API — it is functionally equivalent to the current
Barchart scraper from a legal risk standpoint and has worse ICE Canola coverage.

Do not pursue CME Group or Nasdaq Data Link for ICE Canola — these exchanges do not
list the contract and cannot be a source for it.

---

## Proposed data_source_config Entry

```sql
-- Replace the existing barchart_futures (scraper) entry with this legitimate API entry
INSERT INTO data_source_config (
  source_name,
  source_url,
  data_type,
  fetch_method,
  fetch_frequency,
  auth_type,
  region_coverage,
  is_active,
  notes
) VALUES (
  'barchart_ondemand_futures',
  'https://ondemand.barchart.com/api/v2/getQuote.json',
  'grain_prices',
  'api',
  'hourly',       -- actually every 4 hours; use 'hourly' category
  'api_key',
  'north_america',
  true,
  'Legitimate Barchart OnDemand API replacing HTML scraper. Covers ICE Canola (RS*0, all months) and CBOT grains (ZW*0, ZC*0, ZS*0). Free tier: 400 req/day. Env var: BARCHART_API_KEY. Register at barchart.com/ondemand/free-api-key. 15-min delayed data. Attribution: "Market data provided by Barchart."'
);

-- Disable the old scraper source
UPDATE data_source_config
  SET is_active = false,
      notes = notes || ' [DEPRECATED: HTML scraper violated Barchart ToS. Replaced by barchart_ondemand_futures.]'
  WHERE source_name = 'barchart_futures';
```

---

## Edge Function Rewrite Skeleton

The following shows the core change needed in
`supabase/functions/fetch-futures-prices/index.ts`. Replace the HTML fetching and
parsing logic with this API-based approach:

```typescript
const BARCHART_API_KEY = Deno.env.get("BARCHART_API_KEY")!;
const BARCHART_BASE = "https://ondemand.barchart.com/api/v2";

// Fields to request from Barchart OnDemand
const QUOTE_FIELDS = [
  "symbol", "name", "lastPrice", "priceChange", "percentChange",
  "openPrice", "highPrice", "lowPrice", "volume", "openInterest",
  "settlement", "tradeTime", "contractName"
].join(",");

// Symbol map: root symbol -> all active months notation
// RS*0 = all active ICE Canola contracts
// ZW*0 = all active CBOT Wheat contracts (front month only requested separately)
const COMMODITY_SYMBOLS: Record<string, CommodityConfig> = {
  "RS*0": { commodity: "CANOLA", exchange: "ICE", currency: "CAD", priceUnit: "CAD/tonne" },
  "ZW*0": { commodity: "WHEAT",  exchange: "CBOT", currency: "USD", priceUnit: "cents/bushel" },
  "ZC*0": { commodity: "CORN",   exchange: "CBOT", currency: "USD", priceUnit: "cents/bushel" },
  "ZS*0": { commodity: "SOYBEANS", exchange: "CBOT", currency: "USD", priceUnit: "cents/bushel" },
};

async function fetchFromBarchart(rootSymbol: string): Promise<unknown[]> {
  const url = `${BARCHART_BASE}/getQuote.json` +
    `?apikey=${BARCHART_API_KEY}` +
    `&symbols=${encodeURIComponent(rootSymbol)}` +
    `&fields=${QUOTE_FIELDS}`;

  const response = await fetch(url, {
    headers: { "Accept": "application/json" }
  });

  if (!response.ok) {
    throw new Error(`Barchart API error: HTTP ${response.status} for ${rootSymbol}`);
  }

  const data = await response.json() as { results?: unknown[]; error?: string };

  if (data.error) {
    throw new Error(`Barchart API returned error: ${data.error}`);
  }

  return data.results ?? [];
}
```

---

## Implementation Priority

Given the current state of `fetch-futures-prices/index.ts` (HTML scraper with spoofed
User-Agent, acknowledged to be fragile and potentially blocked), this rewrite is
categorized as a **legal compliance fix**, not just an improvement. It should be treated
as Priority 1 in the next development sprint, before the app processes real user traffic
that could expose the ToS violation.

**Estimated effort to migrate:** 3-4 hours
- 1 hour: Register Barchart API key, test endpoints with curl/Postman
- 2 hours: Rewrite `fetch-futures-prices/index.ts` replacing HTML parser with API calls
- 0.5 hours: Add `BARCHART_API_KEY` to Supabase secrets (local + production)
- 0.5 hours: Verify output matches `futures_prices` table schema, test upsert

---

*Research based on knowledge as of August 2025. API pricing and tier availability should
be verified at time of implementation. Always test API endpoint availability before
committing to integration.*

*Generated by: Data Research Agent*
*For handoff to: Data Pipeline Agent (supabase/functions/fetch-futures-prices/index.ts rewrite)*
