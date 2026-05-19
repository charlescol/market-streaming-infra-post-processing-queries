INSERT INTO "final-kucoin-microstructure-episodes"
WITH classified AS (
  SELECT
    exchange,
    symbol,
    name,
    regime,
    TIME_FLOOR(__time, 'PT1M') AS minute_bucket,
    __time,
    receptionTimeMicro,
    d_micro,
    CASE
      WHEN d_micro < 0 THEN -1
      WHEN d_micro > 0 THEN 1
      ELSE 0
    END AS run_sign
  FROM "final-kucoin-microstructure-re-ext-derived"
  WHERE d_status = 'valid'
    AND d_micro IS NOT NULL
),

marked AS (
  SELECT
    exchange,
    symbol,
    name,
    regime,
    minute_bucket,
    __time,
    receptionTimeMicro,
    d_micro,
    run_sign,
    CASE
      WHEN run_sign != 0
       AND COALESCE(
         LAG(run_sign) OVER (
           PARTITION BY exchange, symbol, name, minute_bucket
           ORDER BY receptionTimeMicro
         ),
         0
       ) != run_sign
      THEN 1
      ELSE 0
    END AS run_start
  FROM classified
),

numbered AS (
  SELECT
    exchange,
    symbol,
    name,
    regime,
    minute_bucket,
    __time,
    receptionTimeMicro,
    d_micro,
    run_sign,
    SUM(run_start) OVER (
      PARTITION BY exchange, symbol, name, minute_bucket
      ORDER BY receptionTimeMicro
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS run_id
  FROM marked
)

SELECT
  MIN(__time) AS __time,
  exchange,
  symbol,
  name,
  regime,
  minute_bucket,
  run_sign,
  run_id,
  
  COUNT(*) AS run_length,

  APPROX_QUANTILE_DS(
    CASE
      WHEN run_sign = -1 THEN -d_micro
      WHEN run_sign = 1 THEN d_micro
    END,
    0.5
  ) AS run_median_size_micro,

  MIN(receptionTimeMicro) AS run_start_time,
  MAX(receptionTimeMicro) AS run_end_time

FROM numbered
WHERE run_sign != 0
GROUP BY
  exchange,
  symbol,
  name,
  regime,
  minute_bucket,
  run_sign,
  run_id
PARTITIONED BY HOUR
CLUSTERED BY exchange, symbol, name, regime, run_sign