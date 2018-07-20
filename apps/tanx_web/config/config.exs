# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :tanx_web, namespace: TanxWeb

# Configures the endpoint
config :tanx_web, TanxWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "Xphhpo7Q+D+CEBnUD8OnZV9jndnhPtty0LkuZ1QKOW/Ao06ea2hE4LCt05luQzSV",
  render_errors: [view: TanxWeb.ErrorView, accepts: ~w(html json)],
  pubsub: [name: TanxWeb.PubSub, adapter: Phoenix.PubSub.PG2]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  level: :info,
  metadata: [:request_id]

config :tanx_web, :generators, context_app: :tanx

config :tanx_web, cluster_active: false

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
