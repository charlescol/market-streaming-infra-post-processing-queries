INSERT INTO "final-kucoin-microstructure-persistent-run-length-quantiles"
WITH stream_level AS (
  SELECT
    "exchange",
    "symbol",
    "name",
    "regime",
    "run_sign",

    APPROX_QUANTILE_DS("run_length", 0.50)
      AS "persistent_run_length_p50",

    APPROX_QUANTILE_DS("run_length", 0.95)
      AS "persistent_run_length_p95",

    COUNT(*) AS "persistent_episode_count"

  FROM "final-kucoin-microstructure-episodes"
  WHERE "regime" IN ('calm', 'high')
    AND "run_sign" IN (-1, 1)
    AND "run_length" >= 3

  GROUP BY
    "exchange",
    "symbol",
    "name",
    "regime",
    "run_sign"
)

SELECT
  MIN(TIMESTAMP '2026-03-03 14:00:00') AS "__time",
  "regime",
  "run_sign",

  APPROX_QUANTILE_DS("persistent_run_length_p50", 0.05)
    AS "persistent_run_length_p50_q05",

  APPROX_QUANTILE_DS("persistent_run_length_p50", 0.95)
    AS "persistent_run_length_p50_q95",

  APPROX_QUANTILE_DS("persistent_run_length_p95", 0.05)
    AS "persistent_run_length_p95_q05",

  APPROX_QUANTILE_DS("persistent_run_length_p95", 0.95)
    AS "persistent_run_length_p95_q95",

  COUNT(*) AS "n_streams",

  SUM("persistent_episode_count") AS "persistent_episode_count"

FROM stream_level
GROUP BY
  "regime",
  "run_sign"

PARTITIONED BY HOUR
CLUSTERED BY "regime", "run_sign"