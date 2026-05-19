INSERT INTO "final-kucoin-microstructure-re-ext-derived"
SELECT
    exchange,
    symbol,
    receptionTimeMicro,
    isFirstUpdateAfterResume,
    name,
    __time,
    regime,
    lag_micro,

    CASE
    WHEN isFirstUpdateAfterResume = 1 THEN 'first_after_resume'
    WHEN prev_sequence IS NULL THEN 'bucket_start'
    WHEN sequence <> prev_sequence + 1 THEN 'sequence_gap'
    ELSE 'valid'
    END AS d_status,

    CASE
    WHEN d_status = 'valid' THEN
        (extractionTimeMicro - prev_extractionTimeMicro)
        - (receptionTimeMicro - prev_receptionTimeMicro)
    ELSE NULL
    END AS d_micro

FROM (
  SELECT
    exchange,
    symbol,
    receptionTimeMicro,
    extractionTimeMicro,
    isFirstUpdateAfterResume,
    name,
    __time,
    sequence,

    CASE
      WHEN __time < TIMESTAMP '2026-03-03 14:30:00' THEN 'calm'
      ELSE 'high'
    END AS regime,

    GREATEST(extractionTimeMicro - receptionTimeMicro, 0) AS lag_micro,

    LAG(extractionTimeMicro) OVER (
      PARTITION BY exchange, symbol, name, TIME_FLOOR(__time, 'PT1M')
      ORDER BY receptionTimeMicro, extractionTimeMicro
    ) AS prev_extractionTimeMicro,

    LAG(receptionTimeMicro) OVER (
      PARTITION BY exchange, symbol, name, TIME_FLOOR(__time, 'PT1M')
      ORDER BY receptionTimeMicro, extractionTimeMicro
    ) AS prev_receptionTimeMicro,

    LAG(sequence) OVER (
      PARTITION BY exchange, symbol, name, TIME_FLOOR(__time, 'PT1M')
      ORDER BY receptionTimeMicro, extractionTimeMicro
    ) AS prev_sequence

  FROM "kucoin-microstructure"
  WHERE extractionTimeMicro IS NOT NULL
    AND __time >= TIMESTAMP '2026-03-03 14:00:00'
    AND __time < TIMESTAMP '2026-03-03 15:00:00'
)
PARTITIONED BY HOUR
CLUSTERED BY exchange, symbol, name, regime