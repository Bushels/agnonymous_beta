// Supabase Edge Function: Fetch Futures Prices from Barchart.com
// Scrapes the "All Futures" page for ICE Canola and CBOT grain contracts
// and upserts settlement/trading data into the futures_prices table.
//
// Data source: https://www.barchart.com/futures/quotes/{symbol}/all-futures
// Symbols:
//   RS*0 = ICE Canola (Winnipeg)
//   ZW*0 = CBOT Wheat
//   ZC*0 = CBOT Corn
//   ZS*0 = CBOT Soybeans
//
// Triggered by: pg_cron (every 4 hours, weekdays only)
// Or manually via: supabase functions invoke fetch-futures-prices

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const SOURCE_NAME = "barchart_futures";

// Realistic browser User-Agent to avoid blocks
const FETCH_HEADERS: Record<string, string> = {
  "User-Agent":
    "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
  Accept:
    "text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8",
  "Accept-Language": "en-US,en;q=0.5",
  "Accept-Encoding": "gzip, deflate, br",
  Connection: "keep-alive",
  "Cache-Control": "no-cache",
};

// Barchart symbol configuration
interface CommodityConfig {
  symbol: string; // Barchart root symbol
  commodity: string; // Normalized name for DB
  exchange: string; // ICE or CBOT
  currency: string; // CAD or USD
  priceUnit: string; // CAD/tonne or cents/bushel
}

const COMMODITY_CONFIGS: CommodityConfig[] = [
  {
    symbol: "RS*0",
    commodity: "CANOLA",
    exchange: "ICE",
    currency: "CAD",
    priceUnit: "CAD/tonne",
  },
  {
    symbol: "ZW*0",
    commodity: "WHEAT",
    exchange: "CBOT",
    currency: "USD",
    priceUnit: "cents/bushel",
  },
  {
    symbol: "ZC*0",
    commodity: "CORN",
    exchange: "CBOT",
    currency: "USD",
    priceUnit: "cents/bushel",
  },
  {
    symbol: "ZS*0",
    commodity: "SOYBEANS",
    exchange: "CBOT",
    currency: "USD",
    priceUnit: "cents/bushel",
  },
];

// Maximum retry attempts for transient errors
const MAX_RETRIES = 3;
const RETRY_BACKOFF_MS = [1000, 3000, 8000]; // Exponential-ish backoff

interface FuturesRow {
  commodity: string;
  exchange: string;
  contract_month: string;
  contract_code: string;
  trade_date: string; // ISO date YYYY-MM-DD
  last_price: number | null;
  change_amount: number | null;
  change_percent: number | null;
  open_price: number | null;
  high_price: number | null;
  low_price: number | null;
  settle_price: number | null;
  prev_close: number | null;
  volume: number | null;
  open_interest: number | null;
  is_front_month: boolean;
  currency: string;
  price_unit: string;
}

/**
 * Parse a numeric string, stripping commas, plus signs, and percent signs.
 * Returns null if the value is empty, 'unch', or unparseable.
 */
function parseNum(value: string | undefined | null): number | null {
  if (!value) return null;
  const cleaned = value.replace(/[,%+s]/g, "").trim();
  if (
    cleaned === "" ||
    cleaned === "unch" ||
    cleaned === "unch." ||
    cleaned === "-"
  ) {
    return null;
  }
  const num = parseFloat(cleaned);
  return isNaN(num) ? null : num;
}

/**
 * Parse a large integer string (volume, open interest) that may have commas.
 */
function parseBigInt(value: string | undefined | null): number | null {
  if (!value) return null;
  const cleaned = value.replace(/[,\s]/g, "").trim();
  if (cleaned === "" || cleaned === "-" || cleaned === "N/A") return null;
  const num = parseInt(cleaned, 10);
  return isNaN(num) ? null : num;
}

/**
 * Decode the Barchart contract code to extract a human-readable contract month.
 * Barchart codes: e.g. RSN26 = Canola July 2026, RSX26 = Canola November 2026
 * Month codes: F=Jan, G=Feb, H=Mar, J=Apr, K=May, M=Jun,
 *              N=Jul, Q=Aug, U=Sep, V=Oct, X=Nov, Z=Dec
 */
const MONTH_CODE_MAP: Record<string, string> = {
  F: "Jan",
  G: "Feb",
  H: "Mar",
  J: "Apr",
  K: "May",
  M: "Jun",
  N: "Jul",
  Q: "Aug",
  U: "Sep",
  V: "Oct",
  X: "Nov",
  Z: "Dec",
};

function decodeContractMonth(contractCode: string): string {
  // Contract codes like RSN26, ZWN26, ZCZ26
  // The month code is the character before the 2-digit year
  if (contractCode.length < 3) return contractCode;

  const yearStr = contractCode.slice(-2);
  const monthCode = contractCode.slice(-3, -2).toUpperCase();
  const monthName = MONTH_CODE_MAP[monthCode];

  if (monthName && /^\d{2}$/.test(yearStr)) {
    return `${monthName}${yearStr}`;
  }

  return contractCode;
}

/**
 * Fetch a URL with retries and exponential backoff.
 */
async function fetchWithRetry(
  url: string,
  headers: Record<string, string>
): Promise<Response> {
  let lastError: Error | null = null;

  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    try {
      const response = await fetch(url, { headers });

      // Don't retry on 403/404 — those are permanent
      if (response.status === 403 || response.status === 404) {
        return response;
      }

      // Retry on 429 (rate limited) or 5xx (server error)
      if (response.status === 429 || response.status >= 500) {
        if (attempt < MAX_RETRIES) {
          const delay = RETRY_BACKOFF_MS[attempt] || 8000;
          console.warn(
            `HTTP ${response.status} on attempt ${attempt + 1}, retrying in ${delay}ms...`
          );
          await new Promise((resolve) => setTimeout(resolve, delay));
          continue;
        }
      }

      return response;
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error));
      if (attempt < MAX_RETRIES) {
        const delay = RETRY_BACKOFF_MS[attempt] || 8000;
        console.warn(
          `Fetch error on attempt ${attempt + 1}: ${lastError.message}, retrying in ${delay}ms...`
        );
        await new Promise((resolve) => setTimeout(resolve, delay));
      }
    }
  }

  throw lastError || new Error(`Failed to fetch ${url} after ${MAX_RETRIES} retries`);
}

/**
 * Try to extract futures data from Barchart HTML.
 *
 * Barchart embeds data in the page in several ways:
 * 1. A <table> with class "bc-futures-overview-table" or similar
 * 2. JSON embedded in script tags or data attributes
 * 3. Standard HTML table rows with contract data
 *
 * We attempt multiple parsing strategies.
 */
function parseHtmlForFutures(
  html: string,
  config: CommodityConfig,
  today: string
): FuturesRow[] {
  const rows: FuturesRow[] = [];

  // --- Strategy 1: Look for JSON data embedded in data-ng-init or __NEXT_DATA__ ---
  const jsonDataMatch = html.match(
    /data-ng-init="[^"]*futuresData\s*=\s*(\[[\s\S]*?\])/
  );
  if (jsonDataMatch) {
    try {
      const futuresData = JSON.parse(jsonDataMatch[1]);
      return parseJsonFuturesData(futuresData, config, today);
    } catch {
      console.warn("Failed to parse embedded JSON from data-ng-init");
    }
  }

  // --- Strategy 2: Look for Barchart's JSON in script tags ---
  const scriptJsonMatch = html.match(
    /"futuresData"\s*:\s*(\[[\s\S]*?\])\s*[,}]/
  );
  if (scriptJsonMatch) {
    try {
      const futuresData = JSON.parse(scriptJsonMatch[1]);
      return parseJsonFuturesData(futuresData, config, today);
    } catch {
      console.warn("Failed to parse JSON from script tag");
    }
  }

  // --- Strategy 3: Parse HTML table rows ---
  // Look for table rows containing contract data
  // Typical Barchart table: Contract | Month | Last | Change | % | Open | High | Low | Volume | OI
  const tableRowRegex =
    /<tr[^>]*>[\s\S]*?<\/tr>/gi;
  const cellRegex = /<t[dh][^>]*>([\s\S]*?)<\/t[dh]>/gi;
  const linkRegex = /<a[^>]*href="[^"]*\/([A-Z0-9]+)"[^>]*>([\s\S]*?)<\/a>/i;
  const tagStripRegex = /<[^>]+>/g;

  const tableMatches = html.match(tableRowRegex);
  if (tableMatches) {
    let frontMonthSet = false;

    for (const rowHtml of tableMatches) {
      const cells: string[] = [];
      let cellMatch: RegExpExecArray | null;
      const cellRe = /<t[dh][^>]*>([\s\S]*?)<\/t[dh]>/gi;

      while ((cellMatch = cellRe.exec(rowHtml)) !== null) {
        cells.push(cellMatch[1].trim());
      }

      // We need at least 7 cells for a valid data row
      if (cells.length < 7) continue;

      // Try to extract contract code from the first cell (usually a link)
      const linkMatch = cells[0].match(linkRegex);
      let contractCode = "";
      let contractLabel = "";

      if (linkMatch) {
        contractCode = linkMatch[1];
        contractLabel = linkMatch[2].replace(tagStripRegex, "").trim();
      } else {
        // Fallback: first cell is plain text with the contract code
        contractCode = cells[0].replace(tagStripRegex, "").trim();
        contractLabel = contractCode;
      }

      // Skip header rows or non-contract rows
      if (
        !contractCode ||
        /^(contract|symbol|month)/i.test(contractCode) ||
        contractCode.length < 3
      ) {
        continue;
      }

      // Validate this looks like a futures contract code
      // E.g., RSN26, ZWN26, ZCZ26, ZSF27
      const rootSymbol = config.symbol.replace("*0", "");
      if (
        !contractCode.toUpperCase().startsWith(rootSymbol.toUpperCase()) &&
        contractCode.length > 6
      ) {
        continue;
      }

      const contractMonth = decodeContractMonth(contractCode);

      // Strip HTML tags from cell values
      const cleanCells = cells.map((c) =>
        c.replace(tagStripRegex, "").trim()
      );

      // Typical column order after contract:
      // [contract, month/label, last, change, %, open, high, low, volume, OI, settlement]
      // But order varies — try a flexible approach
      const isFrontMonth = !frontMonthSet;
      frontMonthSet = true;

      const row: FuturesRow = {
        commodity: config.commodity,
        exchange: config.exchange,
        contract_month: contractMonth,
        contract_code: contractCode,
        trade_date: today,
        last_price: parseNum(cleanCells[1] || cleanCells[2]),
        change_amount: parseNum(cleanCells[2] || cleanCells[3]),
        change_percent: parseNum(cleanCells[3] || cleanCells[4]),
        open_price: parseNum(cleanCells[4] || cleanCells[5]),
        high_price: parseNum(cleanCells[5] || cleanCells[6]),
        low_price: parseNum(cleanCells[6] || cleanCells[7]),
        settle_price: null, // Often not in the main table
        prev_close: null,
        volume: parseBigInt(cleanCells[7] || cleanCells[8]),
        open_interest: parseBigInt(cleanCells[8] || cleanCells[9]),
        is_front_month: isFrontMonth,
        currency: config.currency,
        price_unit: config.priceUnit,
      };

      // Only include rows with at least a last price
      if (row.last_price !== null) {
        rows.push(row);
      }
    }
  }

  return rows;
}

/**
 * Parse structured JSON futures data (if Barchart embeds it).
 */
function parseJsonFuturesData(
  data: Record<string, unknown>[],
  config: CommodityConfig,
  today: string
): FuturesRow[] {
  const rows: FuturesRow[] = [];

  for (let i = 0; i < data.length; i++) {
    const item = data[i];
    const contractCode = (item.symbol as string) || (item.contractCode as string) || "";
    const contractMonth = decodeContractMonth(contractCode);

    rows.push({
      commodity: config.commodity,
      exchange: config.exchange,
      contract_month: contractMonth,
      contract_code: contractCode,
      trade_date: (item.tradeDate as string) || today,
      last_price: parseNum(String(item.lastPrice ?? item.last ?? "")),
      change_amount: parseNum(String(item.priceChange ?? item.change ?? "")),
      change_percent: parseNum(
        String(item.percentChange ?? item.changePercent ?? "")
      ),
      open_price: parseNum(String(item.openPrice ?? item.open ?? "")),
      high_price: parseNum(String(item.highPrice ?? item.high ?? "")),
      low_price: parseNum(String(item.lowPrice ?? item.low ?? "")),
      settle_price: parseNum(
        String(item.settlePrice ?? item.settle ?? item.settlement ?? "")
      ),
      prev_close: parseNum(
        String(item.previousClose ?? item.prevClose ?? "")
      ),
      volume: parseBigInt(String(item.volume ?? "")),
      open_interest: parseBigInt(String(item.openInterest ?? "")),
      is_front_month: i === 0, // First contract is typically front month
      currency: config.currency,
      price_unit: config.priceUnit,
    });
  }

  return rows;
}

/**
 * Fetch and parse futures data for a single commodity.
 */
async function fetchCommodityFutures(
  config: CommodityConfig,
  today: string
): Promise<{ rows: FuturesRow[]; error?: string }> {
  const url = `https://www.barchart.com/futures/quotes/${encodeURIComponent(config.symbol)}/all-futures`;

  console.log(`Fetching ${config.commodity} futures from ${url}`);

  try {
    const response = await fetchWithRetry(url, FETCH_HEADERS);

    if (response.status === 403) {
      const msg = `Barchart returned 403 Forbidden for ${config.commodity}. The site may require JavaScript rendering or is blocking automated requests.`;
      console.warn(msg);
      return { rows: [], error: msg };
    }

    if (response.status === 429) {
      const msg = `Barchart rate limited (429) for ${config.commodity}. Will retry on next scheduled run.`;
      console.warn(msg);
      return { rows: [], error: msg };
    }

    if (!response.ok) {
      const msg = `HTTP ${response.status} ${response.statusText} for ${config.commodity}`;
      console.warn(msg);
      return { rows: [], error: msg };
    }

    const html = await response.text();
    console.log(
      `Downloaded ${config.commodity} page: ${html.length} bytes`
    );

    const rows = parseHtmlForFutures(html, config, today);
    console.log(
      `Parsed ${rows.length} contract rows for ${config.commodity}`
    );

    return { rows };
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    console.error(`Error fetching ${config.commodity}: ${msg}`);
    return { rows: [], error: msg };
  }
}

Deno.serve(async (_req) => {
  const corsHeaders = {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Headers":
      "authorization, x-client-info, apikey, content-type",
    "Content-Type": "application/json",
  };

  // Handle CORS preflight
  if (_req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const startTime = Date.now();
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

  // Today's date in ISO format for trade_date
  const today = new Date().toISOString().split("T")[0];

  // Log pipeline start
  const { data: logEntry } = await supabase
    .from("data_pipeline_logs")
    .insert({
      source_name: SOURCE_NAME,
      status: "started",
      started_at: new Date().toISOString(),
    })
    .select("id")
    .single();

  const logId = logEntry?.id;

  try {
    // Fetch all commodities (sequentially to be polite to Barchart)
    const allRows: FuturesRow[] = [];
    const errors: string[] = [];
    const commoditiesFound: string[] = [];

    for (const config of COMMODITY_CONFIGS) {
      const result = await fetchCommodityFutures(config, today);

      if (result.rows.length > 0) {
        allRows.push(...result.rows);
        commoditiesFound.push(config.commodity);
      }

      if (result.error) {
        errors.push(`${config.commodity}: ${result.error}`);
      }

      // Small delay between requests to be polite
      if (COMMODITY_CONFIGS.indexOf(config) < COMMODITY_CONFIGS.length - 1) {
        await new Promise((resolve) => setTimeout(resolve, 1500));
      }
    }

    // If we got zero rows from all commodities, that's likely a blocking issue
    if (allRows.length === 0) {
      const errorMsg = errors.length > 0
        ? `No futures data retrieved. Errors: ${errors.join("; ")}`
        : "No futures data could be parsed from Barchart pages. The site may require JavaScript rendering — consider using a headless browser or an alternative data source.";

      throw new Error(errorMsg);
    }

    // Batch upsert to futures_prices
    const BATCH_SIZE = 50;
    let totalInserted = 0;

    for (let i = 0; i < allRows.length; i += BATCH_SIZE) {
      const batch = allRows.slice(i, i + BATCH_SIZE);

      const { error } = await supabase.from("futures_prices").upsert(
        batch.map((r) => ({
          commodity: r.commodity,
          exchange: r.exchange,
          contract_month: r.contract_month,
          contract_code: r.contract_code,
          trade_date: r.trade_date,
          last_price: r.last_price,
          change_amount: r.change_amount,
          change_percent: r.change_percent,
          open_price: r.open_price,
          high_price: r.high_price,
          low_price: r.low_price,
          settle_price: r.settle_price,
          prev_close: r.prev_close,
          volume: r.volume,
          open_interest: r.open_interest,
          is_front_month: r.is_front_month,
          currency: r.currency,
          price_unit: r.price_unit,
          fetched_at: new Date().toISOString(),
        })),
        {
          onConflict: "commodity,exchange,contract_month,trade_date",
          ignoreDuplicates: false,
        }
      );

      if (error) {
        throw new Error(
          `Upsert batch ${Math.floor(i / BATCH_SIZE) + 1} failed: ${error.message}`
        );
      }

      totalInserted += batch.length;
      console.log(
        `Upserted batch ${Math.floor(i / BATCH_SIZE) + 1}: ${batch.length} rows`
      );
    }

    const durationMs = Date.now() - startTime;

    // Update pipeline log with success
    if (logId) {
      await supabase
        .from("data_pipeline_logs")
        .update({
          status: "success",
          rows_fetched: allRows.length,
          rows_inserted: totalInserted,
          duration_ms: durationMs,
          completed_at: new Date().toISOString(),
          metadata: {
            commodities_found: commoditiesFound,
            errors: errors.length > 0 ? errors : undefined,
            trade_date: today,
          },
        })
        .eq("id", logId);
    }

    // Update data source config
    await supabase
      .from("data_source_config")
      .update({
        last_fetch_at: new Date().toISOString(),
        last_fetch_status: "success",
        last_fetch_rows: totalInserted,
      })
      .eq("source_name", SOURCE_NAME);

    console.log(
      `Pipeline complete: ${totalInserted} rows in ${durationMs}ms`
    );

    return new Response(
      JSON.stringify({
        success: true,
        rows_fetched: allRows.length,
        rows_inserted: totalInserted,
        commodities: commoditiesFound,
        errors: errors.length > 0 ? errors : undefined,
        duration_ms: durationMs,
      }),
      { headers: corsHeaders }
    );
  } catch (error) {
    const durationMs = Date.now() - startTime;
    const errorMessage =
      error instanceof Error ? error.message : String(error);

    console.error("Pipeline error:", errorMessage);

    // Update log with error
    if (logId) {
      await supabase
        .from("data_pipeline_logs")
        .update({
          status: "error",
          error_message: errorMessage,
          duration_ms: durationMs,
          completed_at: new Date().toISOString(),
        })
        .eq("id", logId);
    }

    // Update data source config
    await supabase
      .from("data_source_config")
      .update({
        last_fetch_at: new Date().toISOString(),
        last_fetch_status: "error",
      })
      .eq("source_name", SOURCE_NAME);

    return new Response(
      JSON.stringify({ success: false, error: errorMessage }),
      { status: 500, headers: corsHeaders }
    );
  }
});
