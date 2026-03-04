// Supabase Edge Function: Fetch PDQ Cash Prices
// Fetches regional grain cash prices from the PDQ (Price & Data Quotes)
// widget API and upserts into the local_cash_prices table.
//
// Data source: https://www.pdqinfo.ca/widget/regional
// Format: JSON with regional average prices by zone and commodity
// Published: Daily at ~2pm CST (weekdays)
// Operated by: Alberta Grains (free public service)
//
// Triggered by: pg_cron (daily at 1am UTC / 6pm MST on weekdays)
// Or manually via: supabase functions invoke fetch-pdq-prices
//
// PDQ Zones:
//   1 = PEACE (AB)
//   2 = N ALTA (AB)
//   3 = S ALTA (AB)
//   4 = NW SASK (SK)
//   5 = SW SASK (SK)
//   6 = NE SASK (SK)
//   7 = SE SASK (SK)
//   8 = W MAN (MB)
//   9 = E MAN (MB)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const PDQ_REGIONAL_URL = "https://www.pdqinfo.ca/widget/regional";

const SOURCE_NAME = "pdq_cash_prices";

// Request headers — honest identification
const FETCH_HEADERS = {
  "User-Agent":
    "Agnonymous-DataPipeline/1.0 (Agricultural Data Hub; contact@agnonymous.com)",
  Accept: "application/json,*/*",
};

// Maximum retry attempts for transient errors
const MAX_RETRIES = 3;
const RETRY_BACKOFF_MS = [1000, 3000, 8000];

// Map PDQ zone IDs to province abbreviations
const ZONE_PROVINCE_MAP: Record<string, string> = {
  "1": "AB",
  "2": "AB",
  "3": "AB",
  "4": "SK",
  "5": "SK",
  "6": "SK",
  "7": "SK",
  "8": "MB",
  "9": "MB",
};

// Map PDQ zone IDs to descriptive names (used as elevator_name)
const ZONE_NAME_MAP: Record<string, string> = {
  "1": "Peace Region",
  "2": "North Alberta",
  "3": "South Alberta",
  "4": "NW Saskatchewan",
  "5": "SW Saskatchewan",
  "6": "NE Saskatchewan",
  "7": "SE Saskatchewan",
  "8": "West Manitoba",
  "9": "East Manitoba",
};

interface PdqCommodity {
  id: number;
  name: string;
  abbr: string;
  label: string;
  code: string;
  bushel_rate: string;
}

interface CashPriceRow {
  source: string;
  elevator_name: string;
  company: string;
  location_province: string;
  commodity: string;
  grade: string | null;
  bid_price_cad: number | null;
  bid_unit: string;
  basis: number | null;
  futures_reference: string | null;
  price_date: string;
  fetched_at: string;
}

/**
 * Fetch a URL with retries and exponential backoff.
 * Retries on network errors, 5xx server errors, and 429 rate limits.
 * Does not retry on 4xx client errors (except 429).
 */
async function fetchWithRetry(
  url: string,
  headers: Record<string, string>
): Promise<Response> {
  let lastError: Error | null = null;

  for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
    try {
      const response = await fetch(url, { headers });

      // Don't retry on 4xx client errors (except 429)
      if (
        response.status >= 400 &&
        response.status < 500 &&
        response.status !== 429
      ) {
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

  throw (
    lastError || new Error(`Failed to fetch ${url} after ${MAX_RETRIES} retries`)
  );
}

/**
 * Parse the PDQ regional JSON response into cash price rows.
 * The JSON structure:
 *   data.commodities: [{id, name, abbr, ...}]
 *   data.zones: [{id, name, ...}]
 *   data.rows.tonnes[zoneId][commodityId]: {new, change, changeRaw}
 *   data.rows.bushels[zoneId][commodityId]: {new, change, changeRaw}
 *   data.sDate: "YYYY-MM-DD"
 */
function parsePdqResponse(json: {
  status: string;
  data: {
    sDate: string;
    commodities: PdqCommodity[];
    zones: { id: number; name: string }[];
    rows: {
      tonnes: Record<string, Record<string, { new: string; change: string; changeRaw: number }>>;
      bushels: Record<string, Record<string, { new: string; change: string; changeRaw: number }>>;
    };
  };
  updatedAt: string;
}): CashPriceRow[] {
  const { data } = json;
  const priceDate = data.sDate; // YYYY-MM-DD
  const fetchedAt = new Date().toISOString();
  const rows: CashPriceRow[] = [];

  // Build commodity lookup by ID
  const commodityMap: Record<number, PdqCommodity> = {};
  for (const c of data.commodities) {
    if (c.id) commodityMap[c.id] = c;
  }

  // Iterate over all zones and commodities in the tonnes data
  const tonnesData = data.rows?.tonnes || {};

  for (const [zoneId, commodities] of Object.entries(tonnesData)) {
    const province = ZONE_PROVINCE_MAP[zoneId];
    const zoneName = ZONE_NAME_MAP[zoneId];
    if (!province || !zoneName) continue;

    for (const [commodityId, priceData] of Object.entries(commodities)) {
      const commodity = commodityMap[parseInt(commodityId, 10)];
      if (!commodity) continue;

      const priceStr = priceData?.new;
      const price = priceStr ? parseFloat(priceStr) : null;

      // Skip rows with no valid price
      if (price === null || isNaN(price)) continue;

      rows.push({
        source: "pdq",
        elevator_name: `PDQ ${zoneName}`,
        company: "PDQ / Alberta Grains",
        location_province: province,
        commodity: commodity.name,
        grade: null, // PDQ regional data doesn't have grade specifics
        bid_price_cad: price,
        bid_unit: "tonne",
        basis: null, // Regional averages don't include basis
        futures_reference: commodity.code || null,
        price_date: priceDate,
        fetched_at: fetchedAt,
      });
    }
  }

  // Also add bushel prices for reference
  const bushelsData = data.rows?.bushels || {};

  for (const [zoneId, commodities] of Object.entries(bushelsData)) {
    const province = ZONE_PROVINCE_MAP[zoneId];
    const zoneName = ZONE_NAME_MAP[zoneId];
    if (!province || !zoneName) continue;

    for (const [commodityId, priceData] of Object.entries(commodities)) {
      const commodity = commodityMap[parseInt(commodityId, 10)];
      if (!commodity) continue;

      const priceStr = priceData?.new;
      const price = priceStr ? parseFloat(priceStr) : null;

      if (price === null || isNaN(price)) continue;

      rows.push({
        source: "pdq",
        elevator_name: `PDQ ${zoneName}`,
        company: "PDQ / Alberta Grains",
        location_province: province,
        commodity: commodity.name,
        grade: null,
        bid_price_cad: price,
        bid_unit: "bushel",
        basis: null,
        futures_reference: commodity.code || null,
        price_date: priceDate,
        fetched_at: fetchedAt,
      });
    }
  }

  return rows;
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
    // 1. Fetch PDQ regional price data
    console.log(`Fetching PDQ regional prices from ${PDQ_REGIONAL_URL}`);
    const response = await fetchWithRetry(PDQ_REGIONAL_URL, FETCH_HEADERS);

    if (!response.ok) {
      throw new Error(
        `Failed to download PDQ data: HTTP ${response.status} ${response.statusText}`
      );
    }

    const jsonText = await response.text();
    console.log(`Downloaded PDQ data: ${jsonText.length} bytes`);

    const json = JSON.parse(jsonText);

    if (json.status !== "ok") {
      throw new Error(
        `PDQ API returned status: ${json.status}`
      );
    }

    // 2. Parse the response into cash price rows
    const rows = parsePdqResponse(json);
    console.log(`Parsed ${rows.length} price rows from PDQ data`);

    if (rows.length === 0) {
      throw new Error("No price rows found in PDQ response");
    }

    // 3. Upsert to local_cash_prices
    const BATCH_SIZE = 500;
    let totalInserted = 0;

    for (let i = 0; i < rows.length; i += BATCH_SIZE) {
      const batch = rows.slice(i, i + BATCH_SIZE);

      const { error } = await supabase.from("local_cash_prices").upsert(
        batch,
        {
          onConflict: "source,elevator_name,commodity,grade,price_date",
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

    // 4. Update pipeline log with success
    if (logId) {
      await supabase
        .from("data_pipeline_logs")
        .update({
          status: "success",
          rows_fetched: rows.length,
          rows_inserted: totalInserted,
          duration_ms: durationMs,
          completed_at: new Date().toISOString(),
          metadata: {
            json_bytes: jsonText.length,
            price_date: json.data?.sDate,
            commodities_found: [
              ...new Set(rows.map((r) => r.commodity)),
            ],
            zones_found: [
              ...new Set(rows.map((r) => r.elevator_name)),
            ],
          },
        })
        .eq("id", logId);
    }

    // 5. Update data source config
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
        rows_fetched: rows.length,
        rows_inserted: totalInserted,
        price_date: json.data?.sDate,
        commodities: [...new Set(rows.map((r) => r.commodity))],
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
      JSON.stringify({
        success: false,
        error: "Pipeline execution failed. Check logs for details.",
      }),
      { status: 500, headers: corsHeaders }
    );
  }
});
