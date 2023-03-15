defmodule Slack.Websocket do
  use WebSockex

  @callback handle_connect(any()) :: {:ok, any()}
  @callback handle_event(any(), any()) :: {:ok, any()}

  defmacro __using__(_opts) do
    quote do
      use WebSockex
      @behaviour Slack.Websocket

      def start_link(url, state) do
        WebSockex.start_link(url, __MODULE__, state)
      end

      defp handle(%{"payload" => %{"event" => event}}, state) do
        handle_event(event, state)
      end

      defp handle(_, state) do
        {:ok, state}
      end

      def handle_frame({:text, msg}, state) do
        case Jason.decode(msg) do
          {:ok, decoded} ->
            decoded
            |> handle(state)

            acknowledge(decoded["envelope_id"], state)

          {:error, e} ->
            IO.inspect(e)
            acknowledge(nil, state)
        end
      end

      def handle_frame({type, msg}, state) do
        IO.puts("Received Message - Type: #{inspect(type)} -- Message: #{inspect(msg)}")
        acknowledge(nil, state)
      end

      def handle_cast({:send, {type, msg} = frame}, state) do
        IO.puts("Sending #{type} frame with payload: #{msg}")
        {:reply, frame, state}
      end

      def acknowledge(nil, state) do
        {:ok, state}
      end

      def acknowledge(envelope_id, state) do
        with encoded <-
               Jason.encode(%{
                 "envelope_id" => envelope_id
               }) do
          case encoded do
            {:ok, e} ->
              IO.inspect(e)
              {:reply, {:text, e}, state}

            e ->
              e
          end
        end
      end
    end
  end

  def handle_frame({:text, msg}, state) do
    case Jason.decode(msg) do
      {:ok, decoded} ->
        handled_res = handle_event(decoded["event"], state)
        Slack.Websocket.acknowledge(decoded["envelope_id"], state)

      {:error, e} ->
        IO.inspect(e)
        Slack.Websocket.acknowledge(nil, state)
    end
  end

  def handle_frame({type, msg}, state) do
    IO.puts("Received Message - Type: #{inspect(type)} -- Message: #{inspect(msg)}")
    acknowledge(nil, state)
  end

  def handle_cast({:send, {type, msg} = frame}, state) do
    IO.puts("Sending #{type} frame with payload: #{msg}")
    {:reply, frame, state}
  end

  def handle_event(ev, st) do
    IO.puts("handle event fallback??")
    IO.inspect(ev)
    IO.inspect(st)
  end

  def acknowledge(nil, state) do
    IO.puts("acknowledge nil")
    {:ok, state}
  end

  def acknowledge(envelope_id, state) do
    IO.puts("Acknowledgin: #{envelope_id}")

    with encoded <-
           Jason.encode(%{
             "envelope_id" => envelope_id
           }) do
      case encoded do
        {:ok, e} ->
          {:reply, {:text, e}, state}

        e ->
          e
      end
    end
  end
end
