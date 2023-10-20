defmodule Summarizer.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      Slack.Config,
      Slack.Userdb,
      Summarizer.Msgdb,
      Summarizer.Tokenizer,
      Summarizer.SlackRtm
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Summarizer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
