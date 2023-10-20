defmodule Summarizer.Chatgpt do
  @type msg :: %{text: String.t(), user: String.t()}

  @default_model "gpt-4"

  defp extract_result(%{message: %{content: content}}), do: content
  defp extract_result(_), do: "sorry something went wrong"

  defp sanitize_name(nil) do
    "unknownuser"
  end

  defp sanitize_name(name) do
    String.replace(name, ~r[\ |\.], "")
  end

  defp role(%{user: userid}, botid) do
    case userid == botid do
      true -> :assistant
      false -> :user
    end
  end

  @doc """
  Groups an array of messages so that each subset has a max token count.
  Takes a {msg, token_count} list and returns chunks of lists of {msg, token_count}
  where each chunk has at most max_token_count tokens
  """
  @spec chunk_msgs_by_tokencount([{msg(), number()}], number()) ::
          {:ok, any()} | {:error, any()}
  def chunk_msgs_by_tokencount(msgs_with_token, max_token_count) do
    Enum.chunk_while(
      msgs_with_token,
      [],
      fn msg_with_token, acc ->
        token_count = elem(msg_with_token, 1)

        if token_count + Enum.sum(Enum.map(acc, fn {_, count} -> count end)) >
             max_token_count do
          {:cont, acc |> Enum.reverse(), [msg_with_token]}
        else
          {:cont, [msg_with_token | acc]}
        end
      end,
      fn acc ->
        {:cont, acc}
      end
    )
  end

  # defp summarize_chunk(chunk, botid, summary_so_far) do
  #   IO.puts("summarizing chunk with #{Enum.count(chunk)} messages")

  #   operator_message_text =
  #     Application.get_env(:summarizer, :partial_summary_prompt)
  #     |> String.replace("{botid}", botid)
  #     |> String.replace("{summary_so_far}", summary_so_far)

  #   operator_message = %ExOpenAI.Components.ChatCompletionRequestMessage{
  #     role: :system,
  #     name: "system",
  #     content: operator_message_text
  #   }

  #   chatgpt_messages =
  #     chunk
  #     # sort messages
  #     |> Enum.filter(fn msg -> msg.user != botid end)
  #     |> Enum.sort(fn a, b ->
  #       Kernel.elem(Float.parse(a.ts), 0) <= Kernel.elem(Float.parse(b.ts), 0)
  #     end)
  #     |> Enum.map(fn msg ->
  #       %ExOpenAI.Components.ChatCompletionRequestMessage{
  #         content: msg.text,
  #         role: role(msg, botid),
  #         name: sanitize_name(msg.user)
  #       }
  #     end)

  #   case ExOpenAI.Chat.create_chat_completion(
  #          [operator_message | chatgpt_messages],
  #          "gpt-3.5-turbo-16k",
  #          temperature: 0.6
  #        ) do
  #     {:ok, result} ->
  #       {:ok, List.first(result.choices) |> extract_result()}
  #   end
  # end

  @doc """
  Summarize fallback function for when token amount is over the model context
  In this case we'll chunk the conversation into pieces and summarize each of them,
  until we run out of messages
  Then do a final pass to summarize everything together

  CURRENTLY NOT USED, MORE OF AN EXPERIMENT
  """

  # @spec summarize_complex([msg], String.t()) :: {:ok, any()} | {:error, any()}
  # def summarize_complex(msgs, botid) do
  #   chunks =
  #     Enum.map(msgs, fn msg ->
  #       {msg, Summarizer.Tokenizer.count_tokens!(msg.text)}
  #     end)
  #     |> chunk_msgs_by_tokencount(8000)
  #     # for each chunk, iterate through all items and remove the token_count entry
  #     |> Enum.map(fn chunk ->
  #       Enum.map(chunk, fn {msg, _} -> msg end)
  #     end)

  #   {:ok,
  #    chunks
  #    |> Enum.reduce("", fn chunk, acc ->
  #      {:ok, content} = summarize_chunk(chunk, botid, acc)
  #      content
  #    end)}
  # end

  @doc """
  Summarize fallback function for when token amount is over the model context
  In this case we'll chunk the conversation into pieces and summarize each of them,
  until we run out of messages
  Then do a final pass to summarize everything together
  """
  @spec summarize_but_with_chunks([msg], String.t(), String.t()) :: {:ok, any()} | {:error, any()}
  def summarize_but_with_chunks(msgs, instruction, botid) do
    chunks =
      Enum.map(msgs, fn msg ->
        {msg, Summarizer.Tokenizer.count_tokens!(msg.text)}
      end)
      |> chunk_msgs_by_tokencount(12000)
      # for each chunk, iterate through all items and remove the token_count entry
      |> Enum.map(fn chunk ->
        Enum.map(chunk, fn {msg, _} -> msg end)
      end)

    result =
      chunks
      |> Enum.map(fn chunk ->
        {:ok, summary} = summarize(chunk, instruction, botid, "gpt-3.5-turbo-16k")
        summary
      end)
      |> Enum.join("\n---\n")

    {:ok, "Conversation is tooooo longgg :persevere:, chunked into parts:\n\n#{result}\n---"}
  end

  @spec summarize([msg], String.t(), String.t(), String.t()) :: {:ok, any()} | {:error, any()}
  def summarize(msgs, instruction, botid, model \\ @default_model) when is_list(msgs) do
    operator_message = %ExOpenAI.Components.ChatCompletionRequestMessage{
      role: :system,
      name: "system",
      content:
        Application.get_env(:summarizer, :prompt)
        |> String.replace("{botid}", botid)
        |> String.replace("{instructions}", instruction)
    }

    chatgpt_messages =
      msgs
      # sort messages
      |> Enum.filter(fn msg -> msg.user != botid end)
      |> Enum.sort(fn a, b ->
        Kernel.elem(Float.parse(a.ts), 0) <= Kernel.elem(Float.parse(b.ts), 0)
      end)
      |> Enum.map(fn msg ->
        %ExOpenAI.Components.ChatCompletionRequestMessage{
          content: msg.text,
          role: role(msg, botid),
          name: sanitize_name(msg.user)
        }
      end)

    case ExOpenAI.Chat.create_chat_completion(
           [operator_message | chatgpt_messages],
           model,
           temperature: 0.6
         ) do
      {:ok, result} ->
        {:ok, List.first(result.choices) |> extract_result()}

      {:error, %{"error" => %{"code" => "context_length_exceeded", "message" => msg}}} ->
        cond do
          model == @default_model ->
            IO.puts("got error message: #{inspect(msg)}, trying with bigger context model")
            summarize(msgs, instruction, botid, "gpt-3.5-turbo-16k")

          model == "gpt-3.5-turbo-16k" ->
            IO.puts("got error message: #{inspect(msg)}, trying with COMPLEX MODE")
            # summarize_complex(msgs, botid)
            summarize_but_with_chunks(msgs, instruction, botid)

          true ->
            {:error, msg}
        end

      {:error, %{"error" => %{"message" => msg}}} ->
        IO.puts("got error message: #{inspect(msg)}")

        if String.contains?(msg, "The server had an error while processing your request.") do
          summarize(msgs, instruction, botid)
        else
          {:error, msg}
        end

      {:error, e} ->
        IO.puts("got error: #{inspect(e)}")
        {:error, e}
    end
  end
end
