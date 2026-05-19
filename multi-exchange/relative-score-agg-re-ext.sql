INSERT INTO "relative-score-agg-re-ext"
SELECT
  TIME_FLOOR(r."__time", 'PT1H') AS "__time",
  r."binanceSymbol",
  r."name",
  r."regime",
  DS_GET_QUANTILE(DS_QUANTILES_SKETCH(r."d_lag_micro"), 0.1) AS "d_lag_micro_d1",
  DS_GET_QUANTILE(DS_QUANTILES_SKETCH(r."d_lag_micro"), 0.2) AS "d_lag_micro_d2",
  DS_GET_QUANTILE(DS_QUANTILES_SKETCH(r."d_lag_micro"), 0.3) AS "d_lag_micro_d3",
  DS_GET_QUANTILE(DS_QUANTILES_SKETCH(r."d_lag_micro"), 0.4) AS "d_lag_micro_d4",
  DS_GET_QUANTILE(DS_QUANTILES_SKETCH(r."d_lag_micro"), 0.5) AS "d_lag_micro_d5",
  DS_GET_QUANTILE(DS_QUANTILES_SKETCH(r."d_lag_micro"), 0.6) AS "d_lag_micro_d6",
  DS_GET_QUANTILE(DS_QUANTILES_SKETCH(r."d_lag_micro"), 0.7) AS "d_lag_micro_d7",
  DS_GET_QUANTILE(DS_QUANTILES_SKETCH(r."d_lag_micro"), 0.8) AS "d_lag_micro_d8",
  DS_GET_QUANTILE(DS_QUANTILES_SKETCH(r."d_lag_micro"), 0.9) AS "d_lag_micro_d9",

  DS_GET_QUANTILE(DS_QUANTILES_SKETCH(r."d_d_micro"), 0.1) AS "d_d_micro_d1",
  DS_GET_QUANTILE(DS_QUANTILES_SKETCH(r."d_d_micro"), 0.2) AS "d_d_micro_d2",
  DS_GET_QUANTILE(DS_QUANTILES_SKETCH(r."d_d_micro"), 0.3) AS "d_d_micro_d3",
  DS_GET_QUANTILE(DS_QUANTILES_SKETCH(r."d_d_micro"), 0.4) AS "d_d_micro_d4",
  DS_GET_QUANTILE(DS_QUANTILES_SKETCH(r."d_d_micro"), 0.5) AS "d_d_micro_d5",
  DS_GET_QUANTILE(DS_QUANTILES_SKETCH(r."d_d_micro"), 0.6) AS "d_d_micro_d6",
  DS_GET_QUANTILE(DS_QUANTILES_SKETCH(r."d_d_micro"), 0.7) AS "d_d_micro_d7",
  DS_GET_QUANTILE(DS_QUANTILES_SKETCH(r."d_d_micro"), 0.8) AS "d_d_micro_d8",
  DS_GET_QUANTILE(DS_QUANTILES_SKETCH(r."d_d_micro"), 0.9) AS "d_d_micro_d9"

FROM "relative-microstructure-re-ext-derived" r
LEFT JOIN "binance-mid-price-re-vs-ext" m
  ON r."binanceSymbol" = m."binanceSymbol"
 AND r."regime" = m."regime"
 AND r."name" = m."name"
 AND r."binanceReceptionTimeMicro" = m."binanceReceptionTimeMicro"
 AND r."binanceExtractionTimeMicro" = m."binanceExtractionTimeMicro"

GROUP BY
  1, 2, 3, 4
PARTITIONED BY HOUR
CLUSTERED BY "binanceSymbol", "name", "regime"