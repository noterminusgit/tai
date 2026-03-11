defmodule Tai.Mixfile do
  use Mix.Project

  def project do
    [
      app: :tai,
      version: "0.0.75",
      elixir: "~> 1.14",
      build_path: "../../_build",
      config_path: "../../config/config.exs",
      deps_path: "../../deps",
      lockfile: "../../mix.lock",
      package: package(),
      start_permanent: Mix.env() == :prod,
      description: description(),
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def application do
    [
      mod: {Tai.Application, []},
      start_phases: [venues: []],
      extra_applications: [
        :phoenix_pubsub,
        :logger,
        :iex,
        :jason,
        :tai_events,
        :ecto_term,
        :postgrex
      ]
    ]
  end

  defp deps do
    [
      {:confex, "~> 3.4"},
      {:ecto, "~> 3.12"},
      {:ecto_sql, "~> 3.12"},
      {:ecto_sqlite3, "~> 0.17", optional: true},
      {:ecto_term, "~> 0.0.1"},
      {:enumerati, "~> 0.0.8"},
      {:ex2ms, "~> 1.7"},
      {:decimal, "~> 2.3"},
      {:fresh, "~> 0.4"},
      {:jason, "~> 1.4"},
      {:juice, "~> 0.0.3"},
      {:murmur, "~> 1.0"},
      {:paged_query, "~> 0.0.2"},
      {:phoenix_pubsub, "~> 2.1"},
      {:polymorphic_embed, "~> 5.0"},
      {:poolboy, "~> 1.5.1"},
      {:postgrex, "~> 0.19.3", optional: true},
      {:req, "~> 0.5"},
      {:table_rex, "~> 3.1"},
      {:tai_events, "~> 0.0.2"},
      {:telemetry, "~> 1.3"},
      {:timex, "~> 3.7"},
      {:stored, "~> 0.0.8"},
      {:vex, "~> 0.7"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:exvcr, "~> 0.15", only: [:dev, :test]},
      {:logger_file_backend_with_formatters, "~> 0.0.1", only: [:dev, :test]},
      {:logger_file_backend_with_formatters_stackdriver, "~> 0.0.4", only: [:dev, :test]},
      {:echo_boy, "~> 0.6", runtime: false, optional: true},
      {:mock, "~> 0.3", only: :test},
      {:ex_doc, "~> 0.35", only: :dev},
      {:mix_audit, "~> 2.1", only: :dev, runtime: false}
    ]
  end

  defp description do
    "A composable, real time, market data and trade execution toolkit"
  end

  defp package do
    %{
      licenses: ["MIT"],
      maintainers: ["Alex Kwiatkowski"],
      links: %{"GitHub" => "https://github.com/fremantle-industries/tai"}
    }
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
