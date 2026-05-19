INSERT INTO "final-kucoin-microstructure-episode-messages"
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
  __time,
  exchange,
  symbol,
  name,
  regime,
  minute_bucket,
  run_sign,
  run_id,
  receptionTimeMicro,
  d_micro,

  CASE
    WHEN run_sign = -1 THEN -d_micro
    WHEN run_sign = 1 THEN d_micro
  END AS episode_size_micro

FROM numbered
WHERE run_sign != 0
PARTITIONED BY HOUR
CLUSTERED BY exchange, symbol, name, regime, run_sign, run_id