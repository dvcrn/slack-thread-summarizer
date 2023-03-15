defmodule Summarizer.Msgdb do
  require Logger
  use Agent

  def start_link(_args \\ []) do
    Logger.info("Starting msgdb")

    Agent.start_link(
      fn -> %{} end,
      name: __MODULE__
    )
  end

  def get(msgid) do
    Agent.get(
      __MODULE__,
      fn db ->
        Map.get(db, msgid)
      end
    )
    |> case do
      nil ->
        Agent.update(__MODULE__, fn db -> Map.put(db, msgid, true) end)
        :ok

      _ ->
        :already_processed
    end
  end
end
