
SET sqlJoinAlgorithm = 'sortMerge';
INSERT INTO "final-relative-mismatch-re-ext"
SELECT
  b."binanceSymbol",
  b."__time",
  em."symbol" as "kucoinSymbol",
  b."binanceSequence",
  b."regime",
  b."binanceReceptionTimeMicro",
  b."binanceExtractionTimeMicro",
  b."binance_value_re",
  b."binance_value_ext",
  b."kucoinReceptionTimeMicro",
  b."kucoinExtractionTimeMicro",
  b."kucoin_value_re",
  b."kucoin_value_ext",
  b."kucoinSequence_re",
  b."kucoinSequence_ext",
  CASE
    WHEN b."kucoin_value_re" IS NULL OR b."kucoin_value_ext" IS NULL THEN NULL
    WHEN b."kucoin_value_re" != b."kucoin_value_ext" THEN 1
    ELSE 0
  END AS "is_mismatch",
  CASE 
    WHEN LOG10(b."binance_value_re" / b."kucoin_value_re")
       * LOG10(b."binance_value_ext" / b."kucoin_value_ext") > 0
    THEN 0
    ELSE 1
  END AS "sign_flip",
  em."run_id",
  em."minute_bucket",
  e."run_length",
  e."run_median_size_micro",
  e."run_sign"
  
FROM "binance-mid-price-re-vs-ext" b

JOIN "final-kucoin-microstructure-episode-messages" em
ON  em."name" = b."name" AND em."regime" = b."regime" AND em."receptionTimeMicro"= b."kucoinReceptionTimeMicro" AND REPLACE(em."symbol", '-', '') = b."binanceSymbol"

JOIN "final-kucoin-microstructure-episodes" e
ON em."name" = e."name" AND em."regime" = e."regime" AND em."symbol" = e."symbol" AND em."run_id" = e."run_id" AND e."minute_bucket" = em."minute_bucket"


PARTITIONED BY HOUR
CLUSTERED BY "binanceSymbol", "regime"