defmodule Summarizer.SlackRtm do
  use Slack.Websocket

  def start_link(opts) do
    IO.puts("starting slack summarizer")
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

  @spec summarize_thread(any, any) :: {:error, any} | {:ok, any}
  def summarize_thread(channel, thread_ts) do
    case Slack.Conversations.replies(channel, thread_ts) do
      {:error, e} ->
        {:error, e}

      {:ok, msgs} ->
        msgs =
          msgs
          |> Enum.map(fn msg ->
            case Slack.Userdb.get(msg.user) do
              {:ok, user} -> {msg, user}
              {:error, _e} -> {msg, nil}
            end
          end)
          |> Enum.filter(fn {_msg, user} -> !Map.get(user, :is_bot) end)
          # fill in the name
          |> Enum.map(fn {msg, user} ->
            replaced_message =
              Slack.Userdb.get_list(msg.mentioned_user_ids)
              |> Kernel.elem(1)
              |> Enum.reduce(msg.text, fn user, msgtext ->
                String.replace(msgtext, user.id, user.name)
              end)

            msg
            |> Map.put(:user, user.name)
            |> Map.put(:text, replaced_message)
          end)

        case Summarizer.Chatgpt.summarize(msgs) do
          {:ok, summary} ->
            {:ok, summary}

          {:error, e} ->
            IO.inspect(e)
            {:error, e}
        end
    end
  end

  @impl true
  @spec handle_event(map, any) :: {:ok, any}
  def handle_event(_message = %{"type" => "message"}, state) do
    IO.inspect("got a message")
    # send_message("I got a message!", message.channel, slack)
    {:ok, state}
  end

  def handle_event(
        _event = %{
          "type" => "app_mention",
          "client_msg_id" => _msg_id,
          "channel" => channel,
          "ts" => ts,
          "thread_ts" => thread_ts,
          "user" => mentioned_user
        },
        state
      ) do
    IO.inspect("got a app_mention")

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

      case summarize_thread(channel, thread_ts) do
        {:ok, summary} ->
          Slack.Chat.post_thread_reply(channel, thread_ts, summary)

        {:error, e} ->
          Slack.Chat.post_thread_reply(
            channel,
            thread_ts,
            "Sorry, something went wrong: #{inspect(e)}"
          )
      end
    end)

    {:ok, state}
  end

  @impl true
  def handle_event(%{"type" => "reaction_added"}, state) do
    IO.inspect("got a new reaction")
    # IO.inspect(message.channel)
    # send_message("I got a message!", message.channel, slack)
    {:ok, state}
  end

  def handle_event(_, state), do: {:ok, state}
end
