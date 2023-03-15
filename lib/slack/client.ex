defmodule Slack.Client do
  use HTTPoison.Base

  def process_response_body(body), do: Jason.decode(body)

  @type context :: :web | :app

  def handle_response(httpoison_response) do
    case httpoison_response do
      {:ok, %HTTPoison.Response{status_code: 200, body: {:ok, body}}} ->
        {:ok, body}

      {:ok, %HTTPoison.Response{body: {:ok, body}}} ->
        {:error, body}

      {:error, %HTTPoison.Error{reason: reason}} ->
        {:error, reason}
    end
  end

  @spec bearer(context) :: {String.t(), String.t()}
  def bearer(:app), do: {"Authorization", "Bearer #{Slack.Config.slack_token()}"}
  def bearer(:web), do: {"Authorization", "Bearer #{Slack.Config.slack_web_token()}"}
  def bearer(_), do: bearer(:web)

  def base_headers(context) do
    [bearer(context), {"Content-type", "application/json"}]
  end

  def request_options(), do: Slack.Config.http_options()

  def construct_url(url) do
    "#{Slack.Config.slack_api_url()}#{url}"
  end

  @spec api_get(String.t(), context(), list(), keyword) :: {:error, any} | {:ok, any}
  def api_get(url, context, params \\ [], request_options \\ []) do
    request_options = Keyword.merge(request_options(), request_options)

    uri = url |> construct_url() |> URI.parse()

    Enum.map(params, fn {k, v} -> "#{k}=#{v}" end)
    |> Enum.reduce(uri, fn v, acc -> URI.append_query(acc, v) end)
    |> URI.to_string()
    |> get(base_headers(context), request_options)
    |> handle_response()
  end

  @spec api_post(String.t(), context) :: {:error, any} | {:ok, any}
  @spec api_post(String.t(), context, list, keyword) :: {:error, any} | {:ok, any}
  def api_post(url, context, params \\ [], request_options \\ []) do
    body =
      params
      |> Enum.into(%{})
      |> Jason.encode([])
      |> elem(1)

    request_options = Keyword.merge(request_options(), request_options)

    url
    |> construct_url()
    |> post(body, base_headers(context), request_options)
    |> handle_response()
  end
end
