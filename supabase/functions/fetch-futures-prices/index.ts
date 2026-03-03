// Supabase Edge Function: Fetch Futures Prices from Barchart OnDemand API
// Uses the legitimate Barchart OnDemand REST API (not HTML scraping).
// Fetches ICE Canola and CBOT grain contract quotes and upserts into futures_prices.
//
// Data source: https://ondemand.barchart.com/api/v2/getQuote.json
// Symbols:
//   RS*0 = ICE Canola (Winnipeg) — all active contract months
//   ZW*0 = CBOT Wheat — all active contract months
//   ZC*0 = CBOT Corn — all active contract months
//   ZS*0 = CBOT Soybeans — all active contract months
//
// Authentication: BARCHART_API_KEY env var (register at barchart.com/ondemand/free-api-key)
// Free tier: 400 requests/day (sufficient for 4-hour schedule)
//
// Triggered by: pg_cron (every 4 hours, weekdays only)
// Or manually via: supabase functions invoke fetch-futures-prices
//
// Attribution: Market data provided by Barchart (https://www.barchart.com)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const BARCHART_API_KEY = Deno.env.get("BARCHART_API_KEY");

const BARCHART_BASE = "https://ondemand.barchart.com/api/v2";
const SOURCE_NAME = "barchart_futures";

// Fields to request from Barchart OnDemand
const QUOTE_FIELDS = [
  "symbol", "name", "lastPrice", "priceChange", "percentChange",
  "openPrice", "highPrice", "lowPrice", "volume", "openInterest",
  "settlement", "previousClose", "tradeTimestamp",
].join(",");

// Barchart symbol configuration
interface CommodityConfig {
  symbol: string;     // Barchart root symbol (e.g. RS*0)
  commodity: string;  // Normalized name for DB
  exchange: string;   // ICE or CBOT
  currency: string;   // CAD or USD
  priceUnit: string;  // CAD/tonne or cents/bushel
}

const COMMODITY_CONFIGS: CommodityConfig[] = [
  { symbol: "RS*0", commodity: "CANOLA", exchange: "ICE", currency: "CAD", priceUnit: "CAD/tonne" },
  { symbol: "ZW*0", commodity: "WHEAT", exchange: "CBOT", currency: "USD", priceUnit: "cents/bushel" },
  { symbol: "ZC*0", commodity: "CORN", exchange: "CBOT", currency: "USD", priceUnit: "cents/bushel" },
  { symbol: "ZS*0", commodity: "SOYBEANS", exchange: "CBOT", currency: "USD", priceUnit: "cents/bushel" },
];

// Retry configuration
const MAX_RETRIES = 3;
const RETRY_BACKOFF_MS = [1000, 3000, 8000];

interface FuturesRow {
  commodity: string;
  exchange: string;
  contract_month: string;
  contract_code: string;
  trade_date: string;
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

// Month codes used by Barchart: F=Jan, G=Feb, H=Mar, J=Apr, K=May, M=Jun,
//                                N=Jul, Q=Aug, U=Sep, V=Oct, X=Nov, Z=Dec
const MONTH_CODE_MAP: Record<string, string> = {
  F: "Jan", G: "Feb", H: "Mar", J: "Apr", K: "May", M: "Jun",
  N: "Jul", Q: "Aug", U: "Sep", V: "Oct", X: "Nov", Z: "Dec",
};

function decodeContractMonth(contractCode: string): string {
  if (contractCode.length < 3) return contractCode;
  const yearStr = contractCode.slice(-2);
  const monthCode = contractCode.slice(-3, -2).toUpperCase();
  const monthName = MONTH_CODE_MAP[monthCode];
  if (monthName && /^\d{2}$/.test(yearStr)) {
    return `${monthName}${yearStr}`;
  }
  return contractCode;
}

function parseNum(value: unknown): number | null {
  if (value === null || value === undefined) return null;
  const str = String(value).replace(/[,%+s]/g, "").trim();
  if (str === "" || str === "unch" || str === "unch." || str === "-" || str === "N/A") return null;
  const num = parseFloat(str);
  return isNaN(num) ? null : num;
}

function parseBigInt(value: unknown): number | null {
  if (value === null || value === undefined) return null;
  const str = String(value).replace(/[,\s]/g, "").trim();
  if (str === "" || str === "-" || str === "N/A") return null;
  const num = parseInt(str, 10);
  return isNaN(num) ? null : num;
}

/**
 * Fetch a URL with retries and exponential backoff for transient errors.
 */
async function fetchWithRetry(url: string): Promise<Response> {
  let lastError: Error | null = null;

  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    try {
      const response = await fetch(url, {
        headers: { "Accept": "application/json" },
      });

      // Don't retry on 4xx client errors (except 429)
      if (response.status >= 400 && response.status < 500 && response.status !== 429) {
        return response;
      }

      // Retry on 429 or 5xx
      if (response.status === 429 || response.status >= 500) {
        if (attempt < MAX_RETRIES) {
          const delay = RETRY_BACKOFF_MS[attempt] || 8000;
          console.warn(`HTTP ${response.status} on attempt ${attempt + 1}, retrying in ${delay}ms...`);
          await new Promise((resolve) => setTimeout(resolve, delay));
          continue;
        }
      }

      return response;
    } catch (error) {
      lastError = error instanceof Error ? error : new Error(String(error));
      if (attempt < MAX_RETRIES) {
        const delay = RETRY_BACKOFF_MS[attempt] || 8000;
        console.warn(`Fetch error on attempt ${attempt + 1}: ${lastError.message}, retrying in ${delay}ms...`);
        await new Promise((resolve) => setTimeout(resolve, delay));
      }
    }
  }

  throw lastError || new Error(`Failed to fetch after ${MAX_RETRIES} retries`);
}

/**
 * Fetch quotes from Barchart OnDemand API for a single commodity.
 */
async function fetchCommodityQuotes(
  config: CommodityConfig,
  today: string,
): Promise<{ rows: FuturesRow[]; error?: string }> {
  const url = `${BARCHART_BASE}/getQuote.json` +
    `?apikey=${BARCHART_API_KEY}` +
    `&symbols=${encodeURIComponent(config.symbol)}` +
    `&fields=${QUOTE_FIELDS}`;

  console.log(`Fetching ${config.commodity} quotes from Barchart OnDemand API`);

  try {
    const response = await fetchWithRetry(url);

    if (!response.ok) {
      const body = await response.text().catch(() => "");
      const msg = `Barchart API returned HTTP ${response.status} for ${config.commodity}: ${body.slice(0, 200)}`;
      console.warn(msg);
      return { rows: [], error: msg };
    }

    const data = await response.json() as {
      status?: { code?: number; message?: string };
      results?: Record<string, unknown>[];
      error?: string;
    };

    // Check for API-level errors
    if (data.status?.code && data.status.code !== 200) {
      const msg = `Barchart API error for ${config.commodity}: ${data.status.message || "Unknown error"}`;
      console.warn(msg);
      return { rows: [], error: msg };
    }

    if (!data.results || data.results.length === 0) {
      const msg = `No results returned for ${config.commodity}`;
      console.warn(msg);
      return { rows: [], error: msg };
    }

    const rows: FuturesRow[] = [];

    for (let i = 0; i < data.results.length; i++) {
      const item = data.results[i];
      const symbol = String(item.symbol || "");
      const contractMonth = decodeContractMonth(symbol);

      // Extract trade date from tradeTimestamp or use today
      let tradeDate = today;
      if (item.tradeTimestamp) {
        const ts = String(item.tradeTimestamp);
        // Format may be ISO or "YYYY-MM-DDTHH:mm:ss"
        if (ts.includes("T") || ts.includes("-")) {
          tradeDate = ts.split("T")[0];
        }
      }

      rows.push({
        commodity: config.commodity,
        exchange: config.exchange,
        contract_month: contractMonth,
        contract_code: symbol,
        trade_date: tradeDate,
        last_price: parseNum(item.lastPrice),
        change_amount: parseNum(item.priceChange),
        change_percent: parseNum(item.percentChange),
        open_price: parseNum(item.openPrice),
        high_price: parseNum(item.highPrice),
        low_price: parseNum(item.lowPrice),
        settle_price: parseNum(item.settlement),
        prev_close: parseNum(item.previousClose),
        volume: parseBigInt(item.volume),
        open_interest: parseBigInt(item.openInterest),
        is_front_month: i === 0,
        currency: config.currency,
        price_unit: config.priceUnit,
      });
    }

    console.log(`Parsed ${rows.length} contracts for ${config.commodity}`);
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
    "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
    "Content-Type": "application/json",
  };

  if (_req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Validate API key is configured
  if (!BARCHART_API_KEY) {
    return new Response(
      JSON.stringify({
        success: false,
        error: "BARCHART_API_KEY not configured. Register at barchart.com/ondemand/free-api-key",
      }),
      { status: 500, headers: corsHeaders },
    );
  }

  const startTime = Date.now();
  const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
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
    const allRows: FuturesRow[] = [];
    const errors: string[] = [];
    const commoditiesFound: string[] = [];

    // Fetch all commodities (sequentially to stay within rate limits)
    for (const config of COMMODITY_CONFIGS) {
      const result = await fetchCommodityQuotes(config, today);

      if (result.rows.length > 0) {
        allRows.push(...result.rows);
        commoditiesFound.push(config.commodity);
      }

      if (result.error) {
        errors.push(`${config.commodity}: ${result.error}`);
      }

      // Small delay between API calls to be respectful of rate limits
      if (COMMODITY_CONFIGS.indexOf(config) < COMMODITY_CONFIGS.length - 1) {
        await new Promise((resolve) => setTimeout(resolve, 500));
      }
    }

    if (allRows.length === 0) {
      throw new Error(
        errors.length > 0
          ? `No futures data retrieved. Errors: ${errors.join("; ")}`
          : "No futures data returned from Barchart OnDemand API.",
      );
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
        { onConflict: "commodity,exchange,contract_month,trade_date", ignoreDuplicates: false },
      );

      if (error) {
        throw new Error(`Upsert batch ${Math.floor(i / BATCH_SIZE) + 1} failed: ${error.message}`);
      }

      totalInserted += batch.length;
    }

    const durationMs = Date.now() - startTime;

    // Update pipeline log
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
            source: "barchart_ondemand_api",
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

    console.log(`Pipeline complete: ${totalInserted} rows in ${durationMs}ms`);

    return new Response(
      JSON.stringify({
        success: true,
        rows_fetched: allRows.length,
        rows_inserted: totalInserted,
        commodities: commoditiesFound,
        errors: errors.length > 0 ? errors : undefined,
        duration_ms: durationMs,
      }),
      { headers: corsHeaders },
    );
  } catch (error) {
    const durationMs = Date.now() - startTime;
    const errorMessage = error instanceof Error ? error.message : String(error);
    console.error("Pipeline error:", errorMessage);

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

    await supabase
      .from("data_source_config")
      .update({
        last_fetch_at: new Date().toISOString(),
        last_fetch_status: "error",
      })
      .eq("source_name", SOURCE_NAME);

    return new Response(
      JSON.stringify({ success: false, error: "Pipeline execution failed. Check logs for details." }),
      { status: 500, headers: corsHeaders },
    );
  }
});
