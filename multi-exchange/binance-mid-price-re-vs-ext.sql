SET sqlJoinAlgorithm = 'sortMerge';
INSERT INTO "binance-mid-price-re-vs-ext"
WITH all_binance_events AS (
  SELECT
    normalizedSymbol,
    regime,
    "name",
    binanceSymbol,
    binanceSequence
  FROM "binance-mid-price-with-kucoin-re"

  UNION

  SELECT
    normalizedSymbol,
    regime,
    "name",
    binanceSymbol,
    binanceSequence
  FROM "binance-mid-price-with-kucoin-ext"
),
merged AS (
  SELECT
    COALESCE(re.__time, ext.__time) AS __time,
    k.normalizedSymbol,
    k.regime,
    k."name",
    k.binanceSymbol,
    k.binanceSequence,

    re.binanceReceptionTimeMicro AS binanceReceptionTimeMicro,
    ext.binanceExtractionTimeMicro AS binanceExtractionTimeMicro,

    re.binance_value AS binance_value_re,
    ext.binance_value AS binance_value_ext,

    re.kucoinReceptionTimeMicro AS kucoinReceptionTimeMicro,
    ext.kucoinExtractionTimeMicro AS kucoinExtractionTimeMicro,

    re.kucoin_value AS kucoin_value_re,
    ext.kucoin_value AS kucoin_value_ext,

    re.kucoinSequence AS kucoinSequence_re,
    ext.kucoinSequence AS kucoinSequence_ext

  FROM all_binance_events k
  LEFT JOIN "binance-mid-price-with-kucoin-re" re
    ON re.normalizedSymbol = k.normalizedSymbol
   AND re.regime = k.regime
   AND re."name" = k."name"
   AND re.binanceSymbol = k.binanceSymbol
   AND re.binanceSequence = k.binanceSequence

  LEFT JOIN "binance-mid-price-with-kucoin-ext" ext
    ON ext.normalizedSymbol = k.normalizedSymbol
   AND ext.regime = k.regime
   AND ext."name" = k."name"
   AND ext.binanceSymbol = k.binanceSymbol
   AND ext.binanceSequence = k.binanceSequence
)
SELECT
  __time,
  regime,
  "name",
  binanceSymbol,
  binanceSequence,
  binanceReceptionTimeMicro,
  binanceExtractionTimeMicro,
  binance_value_re,
  binance_value_ext,
  kucoinReceptionTimeMicro,
  kucoinExtractionTimeMicro,
  kucoin_value_re,
  kucoin_value_ext,
  kucoinSequence_re,
  kucoinSequence_ext
FROM merged
PARTITIONED BY HOUR
CLUSTERED BY normalizedSymbol, regime, "name"