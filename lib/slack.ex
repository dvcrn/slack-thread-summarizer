defmodule Slack do
  defmodule Message do
    defstruct [:type, :user, :text, :thread_ts, :parent_user_id, :ts, :mentioned_user_ids]

    @type t :: %{
            type: String.t(),
            user: String.t(),
            text: String.t(),
            thread_ts: String.t(),
            parent_user_id: String.t(),
            ts: String.t(),
            mentioned_user_ids: [String.t()]
          }

    def from_map(m) when is_map(m) do
      m
      |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
      |> (&struct(__MODULE__, &1)).()
    end
  end

  defmodule User do
    defstruct [:id, :name, :real_name, :is_bot, :is_app_user]

    @type t :: %{
            id: String.t(),
            name: String.t(),
            real_name: String.t(),
            is_bot: boolean(),
            is_app_user: boolean()
          }

    def from_map(m) when is_map(m) do
      m
      |> Enum.map(fn {k, v} -> {String.to_atom(k), v} end)
      |> (&struct(__MODULE__, &1)).()
    end
  end

  defmodule Conversations do
    def extract_user_ids(%{"user_id" => user_id, "type" => "user"}) do
      user_id
    end

    def extract_user_ids(%{"elements" => elements}) when is_list(elements) do
      Enum.map(elements, &extract_user_ids/1)
    end

    def extract_user_ids(%{"blocks" => blocks}) when is_list(blocks) do
      Enum.map(blocks, &extract_user_ids/1)
      |> List.flatten()
      |> Enum.filter(&(!is_nil(&1)))
    end

    def extract_user_ids(_), do: nil

    @spec replies(any, any) :: {:error, any} | {:ok, [Slack.Message.t()]}
    def replies(channel, ts) do
      case Slack.Client.api_get("conversations.replies", :web, channel: channel, ts: ts) do
        {:ok, %{"ok" => true, "messages" => msgs}} ->
          {:ok,
           Enum.map(msgs, fn msg ->
             msg
             |> Map.put("mentioned_user_ids", extract_user_ids(msg))
             |> Slack.Message.from_map()
           end)}

        {:error, e} ->
          {:error, e}
      end
    end

    @spec history(any, any) :: {:error, any} | {:ok, [Slack.Message.t()]}
    def history(channel, ts, limit \\ 5) do
      case Slack.Client.api_get("conversations.history", :web,
             channel: channel,
             latest: ts,
             inclusive: true,
             limit: limit
           ) do
        {:ok, %{"ok" => true, "messages" => msgs}} ->
          {:ok,
           Enum.map(msgs, fn msg ->
             msg
             |> Map.put("mentioned_user_ids", extract_user_ids(msg))
             |> Slack.Message.from_map()
           end)}

        {:error, e} ->
          {:error, e}
      end
    end
  end

  defmodule Users do
    def info(user) do
      case Slack.Client.api_get("users.info", :web, user: user) do
        {:ok, %{"ok" => true, "user" => user}} -> {:ok, Slack.User.from_map(user)}
        {:error, e} -> {:error, e}
      end
    end
  end

  defmodule Chat do
    @spec post_thread_reply(String.t(), String.t(), String.t(), keyword) ::
            {:error, any} | {:ok, any}
    def post_message(channel, text, opts \\ []) do
      Slack.Client.api_post(
        "chat.postMessage",
        :web,
        [
          channel: channel,
          text: text
        ],
        opts
      )
    end

    def post_thread_reply(channel, thread_ts, text, opts \\ []) do
      Slack.Client.api_post(
        "chat.postMessage",
        :web,
        [
          channel: channel,
          text: text,
          thread_ts: thread_ts
        ],
        opts
      )
    end
  end

  defmodule Apps do
    defmodule Connections do
      @spec open :: {:error, any} | {:ok, String.t()}
      def open() do
        case Slack.Client.api_post("apps.connections.open", :app) do
          {:ok, %{"ok" => true, "url" => url}} -> {:ok, url}
          {:error, e} -> {:error, e}
        end
      end
    end
  end

  defmodule Auth do
    def myid() do
      case Slack.Client.api_post("auth.test", :web) do
        {:ok, %{"user_id" => uid}} -> {:ok, uid}
        {:error, e} -> {:error, e}
      end
    end
  end

  defmodule Reactions do
    def remove(channel, reaction, ts) do
      case Slack.Client.api_post("reactions.remove", :web,
             channel: channel,
             name: reaction,
             timestamp: ts
           ) do
        {:ok, _} -> :ok
        {:error, e} -> {:error, e}
      end
    end

    def add(channel, reaction, ts) do
      case Slack.Client.api_post("reactions.add", :web,
             channel: channel,
             name: reaction,
             timestamp: ts
           ) do
        {:ok, _} -> :ok
        {:error, e} -> {:error, e}
      end
    end
  end
end
