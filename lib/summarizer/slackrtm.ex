defmodule Summarizer.SlackRtm do
  use Slack.Websocket

  @enable_normal_mentions Application.compile_env(:summarizer, :enable_normal_mentions, false)

  def start_link(opts) do
    IO.puts("starting slack summarizer")

    case @enable_normal_mentions do
      true ->
        IO.puts("listening to normal messages is ENABLED")

      false ->
        IO.puts("listening to normal messages is DISABLED")
    end

    {:ok, url} = Slack.Apps.Connections.open()

    IO.puts("got slack websocket URL: #{url}")
    start_link(url, opts)
  end

  @impl true
  def handle_connect(state) do
    IO.puts("Connected")
    IO.inspect(state)
    {:ok, state}
  end

  def link_slack_ids(text) do
    regex = ~r/(@?)([UWB][A-Z0-9]{8,})/
    Regex.replace(regex, text, "<@\\2>")
  end

  @spec summarize_messages(list, String.t()) :: {:error, any} | {:ok, any}
  def summarize_messages(msgs, instruction) do
    msgs =
      msgs
      |> Enum.map(fn msg ->
        case Slack.Userdb.get(msg.user) do
          {:ok, user} -> {msg, user}
          {:error, _e} -> {msg, nil}
        end
      end)
      |> Enum.map(fn {msg, user} -> msg end)

    botid =
      case Slack.Userdb.get("botid") do
        {:ok, %{name: botid}} -> botid
        _ -> ""
      end

    case Summarizer.Chatgpt.summarize(msgs, instruction, botid) do
      {:ok, summary} ->
        {:ok, link_slack_ids(summary)}

      {:error, e} ->
        IO.inspect(e)
        {:error, e}
    end
  end

  def handle_event(
        _event = %{
          "type" => "app_mention",
          "client_msg_id" => _msg_id,
          "channel" => channel,
          "ts" => ts,
          "thread_ts" => thread_ts,
          "user" => mentioned_user,
          "text" => text
        },
        state
      ) do
    spawn(fn ->
      case Summarizer.Msgdb.get(ts) do
        :already_processed -> raise "message was already processed, will skip"
        :ok -> :ok
      end

      case Slack.Userdb.get(mentioned_user) do
        {:ok, u} ->
          if u.is_bot do
            IO.puts("user #{mentioned_user} is a bot!!")
            raise("sayonara")
          end

        {:error, e} ->
          raise e
      end

      Slack.Reactions.add(channel, "loading", ts)
      Slack.Reactions.add(channel, "eyes", ts)

      case Slack.Conversations.replies(channel, thread_ts) do
        {:error, e} ->
          {:error, e}

        {:ok, msgs} ->
          case summarize_messages(msgs, text) do
            {:ok, summary} ->
              Slack.Reactions.remove(channel, "loading", ts)
              Slack.Chat.post_thread_reply(channel, thread_ts, summary)

            {:error, e} ->
              Slack.Reactions.remove(channel, "loading", ts)

              Slack.Chat.post_thread_reply(
                channel,
                thread_ts,
                "Sorry, something went wrong: #{inspect(e)}"
              )
          end
      end
    end)

    {:ok, state}
  end

  def handle_event(
        _event = %{
          "type" => "app_mention",
          "client_msg_id" => _msg_id,
          "channel" => channel,
          "ts" => ts,
          "user" => mentioned_user,
          "text" => text
        },
        state
      )
      when @enable_normal_mentions == true do
    IO.inspect("got a app_mention -- direct mention")

    spawn(fn ->
      case Summarizer.Msgdb.get(ts) do
        :already_processed -> raise "message was already processed, will skip"
        :ok -> :ok
      end

      case Slack.Userdb.get(mentioned_user) do
        {:ok, u} ->
          if u.is_bot do
            IO.puts("user #{mentioned_user} is a bot!!")
            raise("sayonara")
          end

        {:error, e} ->
          raise e
      end

      case Slack.Conversations.history(channel, ts, 5) do
        {:error, e} ->
          {:error, e}

        {:ok, msgs} ->
          case summarize_messages(msgs, text) do
            {:ok, summary} ->
              Slack.Chat.post_message(channel, summary)

            {:error, e} ->
              IO.inspect(e)

              Slack.Chat.post_message(
                channel,
                "Sorry, something went wrong: #{inspect(e)}"
              )
          end
      end
    end)

    {:ok, state}
  end

  @impl true
  def handle_event(%{"type" => "reaction_added"}, state) do
    {:ok, state}
  end

  @impl true
  @spec handle_event(map, any) :: {:ok, any}
  def handle_event(_message = %{"type" => "message"}, state) do
    {:ok, state}
  end

  def handle_event(_, state), do: {:ok, state}
end
