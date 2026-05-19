INSERT INTO "final-kucoin-microstructure-re-ext-metrics"
WITH d0_metrics AS (
  SELECT
    MIN(__time) AS __time,
    exchange,
    symbol,
    name,
    regime,

    COUNT(*) AS message_count,
    COUNT(*) / 1800.0 AS message_rate_per_second,

    APPROX_QUANTILE_DS(lag_micro, 0.5) AS median_d0_micro,
    APPROX_QUANTILE_DS(lag_micro, 0.95) AS p95_d0_micro,
    AVG(lag_micro) AS mean_d0_micro

  FROM "final-kucoin-microstructure-re-ext-derived"
  WHERE lag_micro IS NOT NULL
  GROUP BY
    exchange,
    symbol,
    name,
    regime
),

episode_metrics AS (
  SELECT
    exchange,
    symbol,
    name,
    regime,
    run_sign,

    COUNT(*) AS episode_count,

    APPROX_QUANTILE_DS(run_length, 0.95) AS p95_run_length,
    
    APPROX_QUANTILE_DS(run_length, 0.50) AS median_run_length_q05,

    SUM(
      CASE
        WHEN run_length >= 3 THEN run_length
        ELSE 0
      END
    ) * 1.0 / SUM(run_length) AS persistent_run_share,

    SUM(run_length) AS total_run_transitions,

    SUM(
      CASE
        WHEN run_length >= 3 THEN run_length
        ELSE 0
      END
    ) AS persistent_run_transitions,

    SUM(
      CASE
        WHEN run_length >= 3 THEN 1
        ELSE 0
      END
    ) AS persistent_episode_count

  FROM "final-kucoin-microstructure-episodes"
  WHERE run_sign IN (-1, 1)
  GROUP BY
    exchange,
    symbol,
    name,
    regime,
    run_sign
),

run_size_metrics AS (
  SELECT
    exchange,
    symbol,
    name,
    regime,
    run_sign,

    APPROX_QUANTILE_DS(
      CASE
        WHEN run_length >= 3 THEN run_median_size_micro
        ELSE NULL
      END,
      0.5
    ) AS median_persistent_run_size_micro,

    STDDEV(
      CASE
        WHEN run_length >= 3 THEN run_median_size_micro
        ELSE NULL
      END
    ) AS std_persistent_run_size_micro,

    APPROX_QUANTILE_DS(
      CASE
        WHEN run_length < 3 THEN run_median_size_micro
        ELSE NULL
      END,
      0.5
    ) AS median_non_persistent_run_size_micro,

    STDDEV(
      CASE
        WHEN run_length < 3 THEN run_median_size_micro
        ELSE NULL
      END
    ) AS std_non_persistent_run_size_micro

  FROM "final-kucoin-microstructure-episodes"
  WHERE run_sign IN (-1, 1)
    AND run_median_size_micro IS NOT NULL
  GROUP BY
    exchange,
    symbol,
    name,
    regime,
    run_sign
)

SELECT
  d.__time,
  d.exchange,
  d.symbol,
  d.name,
  d.regime,

  d.message_count,
  d.message_rate_per_second,

  d.median_d0_micro,
  d.p95_d0_micro,
  d.mean_d0_micro,

  e.run_sign,

  CASE
    WHEN e.run_sign = -1 THEN 'compression'
    WHEN e.run_sign = 1 THEN 'stretching'
    ELSE NULL
  END AS run_type,

  e.episode_count,
  e.p95_run_length,
  e.median_run_length,
  e.persistent_run_share,
  e.total_run_transitions,
  e.persistent_run_transitions,
  e.persistent_episode_count,

  s.median_persistent_run_size_micro,
  s.std_persistent_run_size_micro,
  s.median_non_persistent_run_size_micro,
  s.std_non_persistent_run_size_micro

FROM d0_metrics d
LEFT JOIN episode_metrics e
  ON d.exchange = e.exchange
 AND d.symbol = e.symbol
 AND d.name = e.name
 AND d.regime = e.regime

LEFT JOIN run_size_metrics s
  ON e.exchange = s.exchange
 AND e.symbol = s.symbol
 AND e.name = s.name
 AND e.regime = s.regime
 AND e.run_sign = s.run_sign

PARTITIONED BY HOUR
CLUSTERED BY exchange, symbol, name, regime, run_sign