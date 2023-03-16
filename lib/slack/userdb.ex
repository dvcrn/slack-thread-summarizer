defmodule Slack.Userdb do
  require Logger
  use Agent

  def start_link(_args \\ []) do
    Logger.info("Starting userdb")

    Agent.start_link(
      fn ->
        case Slack.Auth.myid() do
          {:ok, uid} ->
            IO.puts("bot uid:: #{inspect(uid)}")
            [%{id: "botid", name: uid}]

          _ ->
            []
        end
      end,
      name: __MODULE__
    )
  end

  @spec get(String.t()) :: {:error, any} | {:ok, Slack.User.t()}
  def get(userid) do
    Agent.get(
      __MODULE__,
      fn users ->
        users
        |> Enum.filter(&(&1.id == userid))
        |> case do
          [] ->
            {:error, :no_data}

          u ->
            {:ok, List.first(u)}
        end
      end
    )
    |> case do
      {:ok, u} ->
        {:ok, u}

      {:error, :no_data} ->
        IO.puts("User #{userid} not in DB yet")

        case Slack.Users.info(userid) do
          {:ok, u} ->
            IO.puts("successfully fetched user info for #{userid}")
            Agent.update(__MODULE__, fn state -> [u | state] end)

            {:ok, u}

          e ->
            e
        end
    end
  end

  def get_or_nil(userid) do
    case get(userid) do
      {:ok, u} -> u
      _ -> nil
    end
  end

  def get_list(users) when is_list(users) do
    {:ok, Enum.map(users, &get_or_nil/1)}
  end

  def get_list(_), do: {:ok, []}
end
