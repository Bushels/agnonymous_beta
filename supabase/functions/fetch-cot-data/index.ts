// Supabase Edge Function: Fetch CFTC Commitments of Traders (COT) Data
// Fetches the combined futures + options report from CFTC and upserts
// filtered commodity positions into the cot_positions table.
//
// Data source: https://www.cftc.gov/dea/newcot/deacom.txt
// Format: Comma-delimited text with quoted fields (NOT standard CSV)
// Published: Friday afternoons (typically 3:30pm ET)
//
// Triggered by: pg_cron (weekly, Saturday 06:00 UTC)
// Or manually via: supabase functions invoke fetch-cot-data
//
// Target CFTC commodity codes:
//   135741 = Canola (ICE Winnipeg)
//   001602 = Wheat (CBOT)
//   002602 = Corn (CBOT)
//   005602 = Soybeans (CBOT)

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const COT_REPORT_URL = "https://www.cftc.gov/dea/newcot/deacom.txt";

const SOURCE_NAME = "cftc_cot_weekly";

// Request headers to avoid connection resets from government servers
const FETCH_HEADERS = {
  "User-Agent":
    "Agnonymous-DataPipeline/1.0 (Agricultural Data Hub; contact@agnonymous.com)",
  Accept: "text/plain,*/*",
};

// Maximum retry attempts for transient errors
const MAX_RETRIES = 3;
const RETRY_BACKOFF_MS = [1000, 3000, 8000]; // Exponential-ish backoff

// CFTC commodity code -> normalized name
const COMMODITY_CODE_MAP: Record<string, string> = {
  "135741": "CANOLA",
  "001602": "WHEAT",
  "002602": "CORN",
  "005602": "SOYBEANS",
};

// CFTC commodity code -> exchange
const EXCHANGE_MAP: Record<string, string> = {
  "135741": "ICE",
  "001602": "CBOT",
  "002602": "CBOT",
  "005602": "CBOT",
};

// All target codes for quick lookup
const TARGET_CODES = new Set(Object.keys(COMMODITY_CODE_MAP));

interface CotRow {
  report_date: string; // ISO date YYYY-MM-DD
  commodity: string;
  exchange: string;
  report_type: string;
  commercial_long: number;
  commercial_short: number;
  non_commercial_long: number;
  non_commercial_short: number;
  non_commercial_spreads: number;
  open_interest: number;
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
      if (response.status >= 400 && response.status < 500 && response.status !== 429) {
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
 * Parse a line of the CFTC deacom.txt file.
 * Fields are comma-separated and may be quoted with double quotes.
 */
function parseDelimitedLine(line: string): string[] {
  const fields: string[] = [];
  let current = "";
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    if (char === '"') {
      inQuotes = !inQuotes;
    } else if (char === "," && !inQuotes) {
      fields.push(current.trim());
      current = "";
    } else {
      current += char;
    }
  }
  fields.push(current.trim());
  return fields;
}

/**
 * Parse CFTC date format YYMMDD (e.g., "260228") to ISO date "2026-02-28".
 */
function parseCftcDate(dateStr: string): string | null {
  if (!dateStr || dateStr.length !== 6) return null;

  const yy = parseInt(dateStr.slice(0, 2), 10);
  const mm = dateStr.slice(2, 4);
  const dd = dateStr.slice(4, 6);

  // CFTC uses 2-digit year; assume 20xx for values < 80, 19xx otherwise
  const year = yy < 80 ? 2000 + yy : 1900 + yy;

  return `${year}-${mm}-${dd}`;
}

/**
 * Parse integer from string, handling commas and whitespace.
 */
function parseIntSafe(value: string | undefined): number {
  if (!value) return 0;
  const cleaned = value.replace(/,/g, "").trim();
  const num = parseInt(cleaned, 10);
  return isNaN(num) ? 0 : num;
}

/**
 * Parse the CFTC deacom.txt report text and extract target commodity rows.
 * Uses dynamic header mapping to handle column position changes.
 */
function parseReport(reportText: string): CotRow[] {
  const lines = reportText.split("\n").filter((line) => line.trim().length > 0);

  if (lines.length < 2) {
    throw new Error("Report has no data rows");
  }

  // Parse header row to build column name -> index mapping
  const headerFields = parseDelimitedLine(lines[0]).map((h) =>
    h.replace(/^\uFEFF/, "").trim()
  );

  const colMap: Record<string, number> = {};
  headerFields.forEach((col, idx) => {
    colMap[col] = idx;
  });

  console.log(`Report header: ${headerFields.length} columns`);
  console.log(`Header sample: ${headerFields.slice(0, 20).join(" | ")}`);

  // Map column names to indices dynamically
  // CFTC deacom.txt column names (may have slight variations)
  const findCol = (candidates: string[]): number => {
    for (const name of candidates) {
      // Try exact match first
      if (colMap[name] !== undefined) return colMap[name];
      // Try case-insensitive match
      const lower = name.toLowerCase();
      for (const [key, idx] of Object.entries(colMap)) {
        if (key.toLowerCase() === lower) return idx;
      }
    }
    return -1;
  };

  const marketNameIdx = findCol([
    "Market_and_Exchange_Names",
    "Market and Exchange Names",
  ]);
  const cftcCodeIdx = findCol([
    "CFTC_Commodity_Code",
    "CFTC Commodity Code",
  ]);
  const reportDateIdx = findCol([
    "As_of_Date_In_Form_YYMMDD",
    "As of Date in Form YYMMDD",
  ]);
  const nonCommlLongIdx = findCol([
    "NonComml_Positions-Long_All",
    "Noncommercial Positions-Long (All)",
    "NonComml_Positions_Long_All",
  ]);
  const nonCommlShortIdx = findCol([
    "NonComml_Positions-Short_All",
    "Noncommercial Positions-Short (All)",
    "NonComml_Positions_Short_All",
  ]);
  const nonCommlSpreadsIdx = findCol([
    "NonComml_Positions-Spreading_All",
    "Noncommercial Positions-Spreading (All)",
    "NonComml_Positions_Spreading_All",
  ]);
  const commlLongIdx = findCol([
    "Comml_Positions-Long_All",
    "Commercial Positions-Long (All)",
    "Comml_Positions_Long_All",
  ]);
  const commlShortIdx = findCol([
    "Comml_Positions-Short_All",
    "Commercial Positions-Short (All)",
    "Comml_Positions_Short_All",
  ]);
  const openInterestIdx = findCol([
    "Open_Interest_All",
    "Open Interest (All)",
    "Open_Interest_(All)",
  ]);

  // Validate we found required columns
  const requiredCols: Record<string, number> = {
    CFTC_Commodity_Code: cftcCodeIdx,
    As_of_Date: reportDateIdx,
    NonComml_Long: nonCommlLongIdx,
    NonComml_Short: nonCommlShortIdx,
    Comml_Long: commlLongIdx,
    Comml_Short: commlShortIdx,
    Open_Interest: openInterestIdx,
  };

  const missingCols = Object.entries(requiredCols)
    .filter(([, idx]) => idx === -1)
    .map(([name]) => name);

  if (missingCols.length > 0) {
    throw new Error(
      `Missing required columns: ${missingCols.join(", ")}. Available headers: ${headerFields.slice(0, 30).join(", ")}`
    );
  }

  console.log(
    `Column mapping: code=${cftcCodeIdx}, date=${reportDateIdx}, ` +
      `ncLong=${nonCommlLongIdx}, ncShort=${nonCommlShortIdx}, ncSpreads=${nonCommlSpreadsIdx}, ` +
      `cLong=${commlLongIdx}, cShort=${commlShortIdx}, oi=${openInterestIdx}`
  );

  const rows: CotRow[] = [];

  for (let i = 1; i < lines.length; i++) {
    const fields = parseDelimitedLine(lines[i]);
    if (fields.length < 10) continue; // Skip malformed rows

    const cftcCode = (fields[cftcCodeIdx] || "").trim();

    // Only process target commodities
    if (!TARGET_CODES.has(cftcCode)) continue;

    const commodity = COMMODITY_CODE_MAP[cftcCode];
    const exchange = EXCHANGE_MAP[cftcCode];
    const dateStr = (fields[reportDateIdx] || "").trim();
    const isoDate = parseCftcDate(dateStr);

    if (!isoDate || !commodity) {
      console.warn(
        `Skipping row ${i}: bad date '${dateStr}' or unmapped code '${cftcCode}'`
      );
      continue;
    }

    const marketName = marketNameIdx >= 0 ? fields[marketNameIdx] : "";
    console.log(
      `Found: ${commodity} (${exchange}) — ${isoDate} — ${marketName}`
    );

    rows.push({
      report_date: isoDate,
      commodity,
      exchange,
      report_type: "combined_futures_options",
      commercial_long: parseIntSafe(fields[commlLongIdx]),
      commercial_short: parseIntSafe(fields[commlShortIdx]),
      non_commercial_long: parseIntSafe(fields[nonCommlLongIdx]),
      non_commercial_short: parseIntSafe(fields[nonCommlShortIdx]),
      non_commercial_spreads:
        nonCommlSpreadsIdx >= 0
          ? parseIntSafe(fields[nonCommlSpreadsIdx])
          : 0,
      open_interest: parseIntSafe(fields[openInterestIdx]),
    });
  }

  return rows;
}

/**
 * Calculate net changes vs previous week's data already in the database.
 */
async function calculateNetChanges(
  supabase: ReturnType<typeof createClient>,
  rows: CotRow[]
): Promise<
  (CotRow & {
    commercial_net_change: number | null;
    non_commercial_net_change: number | null;
    open_interest_change: number | null;
  })[]
> {
  const enrichedRows = [];

  for (const row of rows) {
    // Fetch the most recent existing row for this commodity before this report_date
    const { data: prevRow } = await supabase
      .from("cot_positions")
      .select(
        "commercial_long, commercial_short, non_commercial_long, non_commercial_short, open_interest"
      )
      .eq("commodity", row.commodity)
      .eq("exchange", row.exchange)
      .lt("report_date", row.report_date)
      .order("report_date", { ascending: false })
      .limit(1)
      .maybeSingle();

    let commercialNetChange: number | null = null;
    let nonCommercialNetChange: number | null = null;
    let openInterestChange: number | null = null;

    if (prevRow) {
      const prevCommercialNet =
        (prevRow.commercial_long || 0) - (prevRow.commercial_short || 0);
      const prevNonCommercialNet =
        (prevRow.non_commercial_long || 0) -
        (prevRow.non_commercial_short || 0);

      const currentCommercialNet = row.commercial_long - row.commercial_short;
      const currentNonCommercialNet =
        row.non_commercial_long - row.non_commercial_short;

      commercialNetChange = currentCommercialNet - prevCommercialNet;
      nonCommercialNetChange =
        currentNonCommercialNet - prevNonCommercialNet;
      openInterestChange =
        row.open_interest - (prevRow.open_interest || 0);
    }

    enrichedRows.push({
      ...row,
      commercial_net_change: commercialNetChange,
      non_commercial_net_change: nonCommercialNetChange,
      open_interest_change: openInterestChange,
    });
  }

  return enrichedRows;
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
    // 1. Download the CFTC report
    console.log(`Fetching CFTC COT report from ${COT_REPORT_URL}`);
    const response = await fetchWithRetry(COT_REPORT_URL, FETCH_HEADERS);

    if (!response.ok) {
      throw new Error(
        `Failed to download CFTC report: HTTP ${response.status} ${response.statusText}`
      );
    }

    const reportText = await response.text();
    console.log(`Downloaded CFTC report: ${reportText.length} bytes`);

    // 2. Parse the report and filter for target commodities
    const parsedRows = parseReport(reportText);
    console.log(
      `Parsed ${parsedRows.length} rows for target commodities`
    );

    if (parsedRows.length === 0) {
      throw new Error(
        "No target commodity rows found in CFTC report. " +
          "Expected codes: " +
          Array.from(TARGET_CODES).join(", ")
      );
    }

    // 3. Calculate net changes vs previous week
    const enrichedRows = await calculateNetChanges(supabase, parsedRows);
    console.log(`Enriched ${enrichedRows.length} rows with net changes`);

    // 4. Batch upsert to cot_positions
    const BATCH_SIZE = 100;
    let totalInserted = 0;

    for (let i = 0; i < enrichedRows.length; i += BATCH_SIZE) {
      const batch = enrichedRows.slice(i, i + BATCH_SIZE);

      const { error } = await supabase.from("cot_positions").upsert(
        batch.map((r) => ({
          report_date: r.report_date,
          commodity: r.commodity,
          exchange: r.exchange,
          report_type: r.report_type,
          commercial_long: r.commercial_long,
          commercial_short: r.commercial_short,
          non_commercial_long: r.non_commercial_long,
          non_commercial_short: r.non_commercial_short,
          non_commercial_spreads: r.non_commercial_spreads,
          open_interest: r.open_interest,
          commercial_net_change: r.commercial_net_change,
          non_commercial_net_change: r.non_commercial_net_change,
          open_interest_change: r.open_interest_change,
        })),
        {
          onConflict: "report_date,commodity,exchange",
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

    // 5. Update pipeline log with success
    if (logId) {
      await supabase
        .from("data_pipeline_logs")
        .update({
          status: "success",
          rows_fetched: parsedRows.length,
          rows_inserted: totalInserted,
          duration_ms: durationMs,
          completed_at: new Date().toISOString(),
          metadata: {
            report_bytes: reportText.length,
            commodities_found: [
              ...new Set(parsedRows.map((r) => r.commodity)),
            ],
            report_dates: [
              ...new Set(parsedRows.map((r) => r.report_date)),
            ],
          },
        })
        .eq("id", logId);
    }

    // 6. Update data source config
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
        rows_fetched: parsedRows.length,
        rows_inserted: totalInserted,
        commodities: [...new Set(parsedRows.map((r) => r.commodity))],
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
      JSON.stringify({ success: false, error: "Pipeline execution failed. Check logs for details." }),
      { status: 500, headers: corsHeaders }
    );
  }
});
