#!/usr/bin/env bash
set -euo pipefail

ROUTER="http://localhost:8888"

submit_chunk() {
  local chunk_start="$1"
  local chunk_mid="$2"
  local chunk_end="$3"


  local sql
  sql=$(cat <<SQL
SET maxNumTasks = 4;

INSERT INTO "binance-mid-price-with-kucoin-re"
WITH base AS (
  SELECT
    __time,
    CASE
      WHEN exchange = 'EXCHANGE_KUCOIN' THEN REPLACE(symbol, '-', '')
      ELSE symbol
    END AS normalizedSymbol,
    CASE
      WHEN __time < TIMESTAMP '2026-03-03 14:30:00' THEN 'calm'
      ELSE 'high'
    END AS regime,
    exchange,
    symbol,
    "name",
    "value",
    "sequence",
    receptionTimeMicro,
    CAST(
      receptionTimeMicro * 10
      + CASE
          WHEN exchange = 'EXCHANGE_KUCOIN' THEN 0
          ELSE 1
        END
      AS BIGINT
    ) AS ord_key
  FROM TABLE(APPEND('binance-microstructure', 'kucoin-microstructure'))
  WHERE "name" = 'mid_price'
    AND __time >= TIMESTAMP '${chunk_start}'
    AND __time < TIMESTAMP '${chunk_end}'
),
kucoin AS (
  SELECT
    normalizedSymbol,
    ord_key,
    "sequence" AS kucoinSequence,
    receptionTimeMicro AS kucoinReceptionTimeMicro,
    "value" AS kucoin_value
  FROM base
  WHERE exchange = 'EXCHANGE_KUCOIN'
),
annotated AS (
  SELECT
    __time,
    normalizedSymbol,
    regime,
    exchange,
    symbol,
    "name",
    "value",
    "sequence",
    receptionTimeMicro,
    ord_key,
    MAX(
      CASE
        WHEN exchange = 'EXCHANGE_KUCOIN' THEN ord_key
        ELSE NULL
      END
    ) OVER (
      PARTITION BY normalizedSymbol
      ORDER BY ord_key
      ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS lastKucoinOrdKey
  FROM base
)
SELECT
  b.__time,
  b.normalizedSymbol,
  b.symbol AS binanceSymbol,
  b.regime,
  b."name",
  b."sequence" AS binanceSequence,
  b.receptionTimeMicro AS binanceReceptionTimeMicro,
  b."value" AS binance_value,
  k.kucoinSequence,
  k.kucoinReceptionTimeMicro,
  k.kucoin_value
FROM annotated b
LEFT JOIN kucoin k
  ON k.normalizedSymbol = b.normalizedSymbol
 AND k.ord_key = b.lastKucoinOrdKey
WHERE b.exchange = 'EXCHANGE_BINANCE'
  AND b.__time >= TIMESTAMP '${chunk_mid}'
  AND b.__time <  TIMESTAMP '${chunk_end}'
PARTITIONED BY HOUR
CLUSTERED BY normalizedSymbol, regime, "name"
SQL
)
  local payload
  payload=$(jq -n --arg query "$sql" '{query: $query}')

  local task_id
  task_id=$(curl -sS -X POST \
    "${ROUTER}/druid/v2/sql/task" \
    -H 'Content-Type: application/json' \
    -d "$payload" | jq -r '.taskId')

  echo "Submitted chunk ${chunk_start} -> ${chunk_end}, task=${task_id}"

  while true; do
    local status
    status=$(curl -sS "${ROUTER}/druid/indexer/v1/task/${task_id}/status" | jq -r '.status.status')
    echo "Task ${task_id}: ${status}"
    if [[ "$status" == "SUCCESS" ]]; then
      break
    fi
    if [[ "$status" == "FAILED" ]]; then
      echo "Task failed: ${task_id}" >&2
      exit 1
    fi
    sleep 5
  done
}

python3 - <<'PY' | while IFS='|' read -r chunk_start chunk_mid chunk_end; do
from datetime import datetime, timedelta

start = datetime(2026, 3, 3, 14, 00, 0)
end = datetime(2026, 3, 3, 14, 55, 0)
step = timedelta(seconds=30)

print(f"{start:%Y-%m-%d %H:%M:%S}|{start:%Y-%m-%d %H:%M:%S}|{(start + step):%Y-%m-%d %H:%M:%S}")

cur = start
while cur + timedelta(minutes=1) <= end:
    mid = cur + timedelta(seconds=30)
    nxt = cur + timedelta(minutes=1)
    print(f"{cur:%Y-%m-%d %H:%M:%S}|{mid:%Y-%m-%d %H:%M:%S}|{nxt:%Y-%m-%d %H:%M:%S}")
    cur += step
PY
  submit_chunk "$chunk_start" "$chunk_mid" "$chunk_end"
done