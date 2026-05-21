# Market Streaming Infrastructure Post-Processing Queries

Apache Druid queries used for the offline analysis of the real-time market-data pipeline.

This repository is part of the [Real-Time Market Data System](https://github.com/charlescol/real-time-market-data-system). It contains the SQL queries and small helper scripts used to derive analysis tables from the stored pipeline outputs.

The queries are designed to run on the Apache Druid analysis environment defined in [market-streaming-infra-post-processing](https://github.com/charlescol/market-streaming-infra-post-processing).

The initial datasources are:

```text
kucoin-microstructure
binance-microstructure
```

They correspond to the data ingested into Druid during the live experiment.
Derived datasources were then generated using the post-processing queries from this repository.

## Scope

- Extracting timing and run-level metrics from individual streams.
- Building multi-exchange derived tables used to study cross-exchange matching and downstream signal changes.

## Repository structure

```
├── metric-extraction/ # Per-stream timing metrics and episode tables
└── multi-exchange/ # Cross-exchange matching and dislocation queries
```
