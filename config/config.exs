# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.

# General application configuration
use Mix.Config

sentry_dsn = System.get_env("SENTRY_DSN")
mailgun_api_key = System.get_env("MAILGUN_API_KEY")
domain = System.get_env("DOMAIN")
site_id = System.get_env("CUSTOMER_IO_SITE_ID")
customerio_api_key = System.get_env("CUSTOMER_IO_API_KEY")
aws_key_id = System.get_env("AWS_ACCESS_KEY_ID")
aws_secret_key = System.get_env("AWS_SECRET_ACCESS_KEY")
bucket_name = System.get_env("BUCKET_NAME", "papercups-files")
region = System.get_env("AWS_REGION")
smtp_relay = System.get_env("SMTP_RELAY")
smtp_port = System.get_env("SMTP_PORT")
smtp_username = System.get_env("SMTP_USERNAME")
smtp_password = System.get_env("SMTP_PASSWORD")
smtp_dkim = System.get_env("SMTP_DKIM")
smtp_dkim_key = System.get_env("SMTP_DKIM_KEY")
ses_region = System.get_env("SES_REGION")
ses_access_key = System.get_env("SES_ACCESS_KEY")
ses_secret = System.get_env("SES_SECRET")

config :chat_api,
  environment: Mix.env(),
  ecto_repos: [ChatApi.Repo],
  generators: [binary_id: true]

config :chat_api, ChatApi.Repo, migration_timestamps: [type: :utc_datetime_usec]

# Configures the endpoint
config :chat_api, ChatApiWeb.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "9YWmWz498gUjiMQXLq2PX/GcB5uSlqPmcxKPJ49k0vR+6ytuSydFFyDDD3zwRRWi",
  render_errors: [view: ChatApiWeb.ErrorView, accepts: ~w(json), layout: false],
  pubsub_server: ChatApi.PubSub,
  live_view: [signing_salt: "pRVXwt3k"]

config :logger,
  backends: [:console, Sentry.LoggerBackend]

# Configures Elixir's Logger
config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

config :logger, Sentry.LoggerBackend,
  # Also send warn messages
  level: :warn,
  # Send messages from Plug/Cowboy
  excluded_domains: [],
  # Send messages like `Logger.error("error")` to Sentry
  capture_log_messages: true

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Set up timezone database
config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :tesla, adapter: Tesla.Adapter.Hackney

# Configure Swagger
config :phoenix_swagger, json_library: Jason

config :chat_api, :phoenix_swagger,
  swagger_files: %{
    "priv/static/swagger.json" => [
      # phoenix routes will be converted to swagger paths
      router: ChatApiWeb.Router,
      # (optional) endpoint config used to set host, port and https schemes.
      endpoint: ChatApiWeb.Endpoint
    ]
  }

# Configure Sentry
config :sentry,
  dsn: sentry_dsn,
  environment_name: Mix.env(),
  included_environments: [:prod],
  enable_source_code_context: true,
  root_source_code_path: File.cwd!()

config :pow, Pow.Postgres.Store,
  repo: ChatApi.Repo,
  schema: ChatApi.Auth.PowSession

config :chat_api, :pow,
  user: ChatApi.Users.User,
  repo: ChatApi.Repo,
  cache_store_backend: Pow.Postgres.Store

config :chat_api, Oban,
  repo: ChatApi.Repo,
  plugins: [Oban.Plugins.Pruner],
  queues: [default: 10, events: 50, mailers: 20],
  crontab: [
    # Hourly example worker
    {"0 * * * *", ChatApi.Workers.Example},
    {"0 * * * *", ChatApi.Workers.ArchiveStaleClosedConversations},
    # Sends everyday at 2pm UTC/9am EST
    {"0 14 * * *", ChatApi.Workers.SendPgNewsletter}
    # TODO: uncomment this after testing manually
    # {"0 * * * *", ChatApi.Workers.ArchiveStaleFreeTierConversations}
  ]

# Configure SMTP
config :chat_api, ChatApi.Mailers.Smtp,
  adapter: Swoosh.Adapters.SMTP,
  relay: smtp_relay,
  username: smtp_username,
  password: smtp_password,
  ssl: false,
  tls: :always,
  auth: :always,
  port: smtp_port,
  dkim: [
    s: smtp_dkim, d: domain,
    private_key: {:pem_plain, smtp_dkim_key}
  ],
  retries: 2,
  no_mx_lookups: false

# Configure SES
config :chat_api, ChatApi.Mailers.AmazonSES,
  adapter: Swoosh.Adapters.AmazonSES,
  region: ses_region,
  access_key: ses_access_key,
  secret: ses_secret


# Configure Mailgun
config :chat_api, ChatApi.Mailers.Mailgun,
  adapter: Swoosh.Adapters.Mailgun,
  api_key: mailgun_api_key,
  domain: domain

config :chat_api, ChatApi.Mailers.Gmail, adapter: Swoosh.Adapters.Gmail

config :customerio,
  site_id: site_id,
  api_key: customerio_api_key

case System.get_env("PAPERCUPS_STRIPE_SECRET") do
  "sk_" <> _rest = api_key ->
    config :stripity_stripe, api_key: api_key

  _ ->
    nil
end

config :ex_aws,
  access_key_id: aws_key_id,
  secret_access_key: aws_secret_key,
  s3: [
    scheme: "https://",
    host: bucket_name <> ".s3.amazonaws.com",
    region: region
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
