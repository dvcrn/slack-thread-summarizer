defmodule Summarizer.Chatgpt do
  @type msg :: %{text: String.t(), user: String.t()}

  @operator_message %ExOpenAI.Components.ChatCompletionRequestMessage{
    role: :system,
    name: "system",
    content: """
    You are a summarizing program. Your task is to provide a summary of a conversation, so that users don't have to read the potentially long conversation to get the latest status and important details.

    Consider all messages and provide a concise summarization of the important details and key details of the conversation
    - Start your output with "Summary: ", followed by the bulletpoints
    - Keep bulletpoints SHORT AND CONCISE, and stick to the facts
    - Include all relevant key details such as numbers, or how people feel about certain proposals
    - Focus on the core of the discussion and the conclusion up to this point
    - Include names if relevant to the core of the conversation, such as if a person said something important, or is the focus of the discussion
    - If there are any undecided points that require an action from someone, or if any clear next actions are outlined alreaady, or if any blockers have not been resolved yet, or if points need further clarification, summarize those under a "Potential Next Actions / Needs clarification" key. DO NOT WRITE THIS SECTION AT ALL IF THERE ARE NO NEXT ACTIONS! REMOVE IT FROM THE TEMPLATE IN THAT CASE!
    - If you identify points that look like they need clarification, include those as well into the "Potential Next Actions / Needs Clarification" section

    Use this template for output:
    ```
    Summary:

    -

    Potential Next Actions / Needs clarification:

    -
    ```
    """
  }

  defp extract_result(%{message: %{content: content}}), do: content
  defp extract_result(_), do: "sorry something went wrong"

  defp sanitize_name(name) do
    String.replace(name, ~r[\ |\.], "")
  end

  @spec summarize([msg]) :: {:ok, any()} | {:error, any()}
  def summarize(msgs) when is_list(msgs) do
    chatgpt_messages =
      msgs
      |> Enum.map(fn msg ->
        %ExOpenAI.Components.ChatCompletionRequestMessage{
          content: "#{msg.user}: #{msg.text}",
          role: :user,
          name: sanitize_name(msg.user)
        }
      end)

    case ExOpenAI.Chat.create_chat_completion(
           [@operator_message | chatgpt_messages],
           "gpt-3.5-turbo",
           temperature: 0.6
         ) do
      {:ok, result} -> {:ok, List.first(result.choices) |> extract_result()}
      {:error, e} -> {:error, e}
    end
  end
end
