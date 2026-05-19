SET sqlJoinAlgorithm = 'sortMerge';
INSERT INTO "relative-microstructure-re-ext-derived"
SELECT
  b."__time",
  b."regime",
  b."name",
  b."binanceSymbol",
  b."binanceReceptionTimeMicro",
  b."binanceExtractionTimeMicro",

  bm."lag_micro" AS "binance_lag_micro",
  km."lag_micro" AS "kucoin_lag_micro",

  bm."d_micro" AS "binance_d_micro",
  km."d_micro" AS "kucoin_d_micro",

  bm."lag_micro" - km."lag_micro" AS "d_lag_micro",
  bm."d_micro" - km."d_micro" AS "d_d_micro"

FROM "binance-mid-price-re-vs-ext" b

LEFT JOIN "binance-microstructure-re-ext-derived" bm
  ON b."name" = bm."name"
 AND b."binanceSymbol" = bm."symbol"
 AND b."binanceReceptionTimeMicro" = bm."receptionTimeMicro"

LEFT JOIN "kucoin-microstructure-re-ext-derived" km
  ON b."name" = km."name"
 AND b."binanceSymbol" = REPLACE(km."symbol", '-', '')
 AND b."kucoinReceptionTimeMicro" = km."receptionTimeMicro"
 
PARTITIONED BY HOUR
CLUSTERED BY "binanceSymbol"