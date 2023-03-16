import Config

config :summarizer,
  slack_app_token: System.get_env("SLACK_APP_TOKEN"),
  slack_web_token: System.get_env("SLACK_WEB_TOKEN")

config :ex_openai,
  api_key: System.get_env("OPENAI_API_KEY"),
  organization_key: System.get_env("OPENAI_ORGANIZATION_KEY"),
  http_options: [recv_timeout: 50_000]
