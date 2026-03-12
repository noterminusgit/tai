# ADR-001: Baseline Metrics

**Date**: 2026-03-11
**Status**: Accepted

## Context

Before making any improvements to documentation, type coverage, and test coverage, we need baseline metrics to measure progress against.

## Metrics Captured

### Test Suite (2026-03-11)

| Metric | Value |
|--------|-------|
| Total tests | 620 (tai app) + 5 (examples) = 625 |
| Passing | 582 (tai) + 3 (examples) = 585 |
| Failing | 38 (tai, venue adapter HTTP tests with dummy credentials) + 2 (examples, stream tests) = 40 |
| Test runtime | ~57s |

**Note**: The 38 tai failures are venue adapter integration tests that make real HTTP calls (accounts, products, fees, positions) with dummy API credentials. The 2 examples failures are E2E stream connection tests. All non-network-dependent tests pass.

### Dialyzer (2026-03-11)

| Metric | Value |
|--------|-------|
| Suppressed warnings (.dialyzer_ignore.exs) | 46 entries (93 lines) |
| Active warnings | 10 |
| Warning types | 9x `callback_arg_type_mismatch` (Binance: 4, Kraken: 4, Gdax: 1), 1x `pattern_match_cov` (Bitmex) |

### Known Bugs

| Bug | Location | Description |
|-----|----------|-------------|
| Trade handler copy-paste bug | `apps/tai/lib/tai/advisor.ex:103-104` | Trade handler references `state.market_quotes` instead of `state.trades` — **FIXED in this changeset** |

### Type Coverage (2026-03-11 - Pre-improvement)

| Metric | Value |
|--------|-------|
| Files with public functions but no @spec/@impl | 109 |

## Progress Updates

### 2026-03-12 - Phase 1-5 Complete

| Metric | Before | After | Change |
|--------|--------|-------|--------|
| Total tests | 625 | 675 | +50 |
| Tests passing | 585 | 637 | +52 |
| Files without @spec/@impl | 109 | 35 | -74 (68% reduction) |
| @impl true on venue adapters | 1 (Stub) | 11 (all) | +10 |
| @spec on transition modules | 0/19 | 19/19 | +19 |
| @spec on venue adapter impls | 0/~60 | ~39/~60 | +39 |
| @spec on commander module | 0/24 | 24/24 | +24 |
| Architecture docs | 0 | 8 | +8 |
| Guardrails docs | 0 | 5 | +5 |
| ADRs | 0 | 4 | +4 |

## Decision

Use these baseline metrics to track improvement across documentation, testing, and type coverage phases.
