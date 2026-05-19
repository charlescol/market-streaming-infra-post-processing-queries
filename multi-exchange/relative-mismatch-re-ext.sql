SET sqlJoinAlgorithm = 'sortMerge';
INSERT INTO "relative-mismatch-re-ext"
SELECT
  m."__time",
  m."binanceSymbol",
  m."regime",
  m."binanceSequence",
  m."kucoin_value_re",
  m."kucoin_value_ext",
  m."binanceReceptionTimeMicro",
  m."binanceExtractionTimeMicro",
  CASE WHEN m."kucoin_value_re" != m."kucoin_value_ext" THEN 1 ELSE 0 END AS "is_mismatch", 
  10000 * LOG10(m."binance_value_re" / m."kucoin_value_re") AS "mid_price_dislocation_bps_re",
  10000 * LOG10(m."binance_value_ext" / m."kucoin_value_ext") AS "mid_price_dislocation_bps_ext",
  10000 * LOG10(m."kucoin_value_re" / m."kucoin_value_ext") AS "error_bps",
  CASE 
    WHEN LOG10(m."binance_value_re" / m."kucoin_value_re") 
         / LOG10(m."binance_value_ext" / m."kucoin_value_ext") > 0
    THEN 0
    ELSE 1
  END AS "sign_flip",
  r."d_lag_micro",
  r."d_d_micro",
  r."binance_lag_micro",
  r."kucoin_lag_micro",
  r."binance_d_micro",
  r."kucoin_d_micro",
  qd."q_d_arrival_p50",
  qd."q_d_extraction_p50"

FROM "binance-mid-price-re-vs-ext" m
INNER JOIN "relative-microstructure-re-ext-derived" r
    ON r."binanceSymbol" = m."binanceSymbol"
    AND r."regime" = m."regime"
    AND r."name" = m."name"
    AND r."binanceReceptionTimeMicro" = m."binanceReceptionTimeMicro"
    AND r."binanceExtractionTimeMicro" = m."binanceExtractionTimeMicro"
INNER JOIN "kucoin-score-agg-re-ext" qd
    ON qd."name" = m."name"
    AND qd."regime" = m."regime"
    AND REPLACE(qd."symbol", '-', '') = m."binanceSymbol"

WHERE m."kucoin_value_re" IS NOT NULL
    AND m."kucoin_value_ext" IS NOT NULL
    AND qd."q_d_arrival_p50" IS NOT NULL
    AND 10 * qd."q_d_arrival_p50" > ABS(m."binanceReceptionTimeMicro" - m."kucoinReceptionTimeMicro")
    AND 10 * qd."q_d_extraction_p50" > ABS(m."binanceExtractionTimeMicro" - m."kucoinExtractionTimeMicro")

PARTITIONED BY HOUR
CLUSTERED BY "binanceSymbol", "regime"