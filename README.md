# Tai - Orchestrate Your Trading

[![hex.pm version](https://img.shields.io/hexpm/v/tai.svg?style=flat)](https://hex.pm/packages/tai)

A composable, real time, market data and trade execution toolkit. Built with [Elixir](https://elixir-lang.org/), runs on the [Erlang virtual machine](http://erlang.org/faq/implementations.html)

[Getting Started](./docs/GETTING_STARTED.md) | [Built with Tai](./docs/BUILT_WITH_TAI.md) | [Commands](./docs/COMMANDS.md) | [Architecture](./docs/ARCHITECTURE.md) | [Examples](./apps/examples) | [Configuration](./docs/CONFIGURATION.md) | [Observability](./docs/OBSERVABILITY.md)

## What Can I Do? TLDR;

Stream market data to create and manage orders with a near-uniform API across multiple venues

Here's an example of an advisor that logs the spread between multiple products on multiple venues

[![asciicast](https://asciinema.org/a/259561.svg)](https://asciinema.org/a/259561)

## Supported Venues

| Venue          | Live Order Book | Accounts | Orders | Products | Fees |
| -------------- | :-------------: | :------: | :----: | :------: | :--: |
| Binance        |       [x]       |   [x]    |  [x]   |   [x]    | [x]  |
| BitMEX         |       [x]       |   [x]    |  [x]   |   [x]    | [x]  |
| Coinbase       |       [x]       |   [x]    |  [ ]   |   [x]    | [x]  |
| Deribit        |       [x]       |   [x]    |  [ ]   |   [x]    | [x]  |
| Kraken         |       [x]       |   [x]    |  [x]   |   [x]    | [x]  |
| OkEx           |       [x]       |   [x]    |  [x]   |   [x]    | [x]  |
| Delta Exchange  |       [x]       |   [ ]    |  [ ]   |   [x]    | [x]  |
| Huobi          |       [x]       |   [ ]    |  [ ]   |   [x]    | [ ]  |
| Bybit          |       [ ]       |   [ ]    |  [ ]   |   [x]    | [ ]  |

## Install

`tai` requires Elixir 1.14+ & Erlang/OTP 25+. Add `tai` to your list of dependencies in `mix.exs`

```elixir
def deps do
  [
    {:tai, git: "https://github.com/noterminusgit/tai.git"}
    # Choose your order data store
    # {:ecto_sqlite3, "~> 0.17"}
    # {:postgrex, "~> 0.19"}
  ]
end
```

Create an `.iex.exs` file in the root of your project and import the `tai` helper

```elixir
# .iex.exs
Application.put_env(:elixir, :ansi_enabled, true)

import Tai.IEx
```

Run the `setup` mix task to:

* Download dependencies
* Create an orders database
* Generate tai migrations for the orders database
* Run migrations

```bash
$ mix setup
```

## Usage

`tai` runs as an OTP application.

During development we can leverage `mix` to compile and run our application with an
interactive Elixir shell that imports the set of `tai` helper [commands](./docs/COMMANDS.md).

```bash
iex -S mix
```

## Upgrading Tai

Bump the required version number in `mix.exs` and download the dependencies.

```bash
$ mix deps.update tai
```

Regenerate new or updated migrations

```bash
$ mix tai.gen.migration
```

Rerun ecto migrations

```bash
$ mix ecto.migrate
```

## Key Dependencies

| Library | Purpose |
| ------- | ------- |
| [Req](https://hex.pm/packages/req) | HTTP client (replaced HTTPoison) |
| [Fresh](https://hex.pm/packages/fresh) | WebSocket client (replaced WebSockex) |
| [Ecto](https://hex.pm/packages/ecto) | Order persistence |
| [Phoenix PubSub](https://hex.pm/packages/phoenix_pubsub) | Internal event bus |

All venue API integrations (Binance, BitMEX, Coinbase, Deribit, Kraken, OkEx, etc.) are implemented directly within Tai using Req -- no external exchange client libraries are required.

## Help Wanted :)

If you think this `tai` thing might be worthwhile and you don't see a feature
or venue listed we would love your contributions to add them! Feel free to
drop us an email or open a Github issue.

## Authors

- Alex Kwiatkowski - alex+git@fremantle.io

## License

`tai` is released under the [MIT license](./LICENSE.md)
