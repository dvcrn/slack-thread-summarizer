defmodule SummarizerTest do
  use ExUnit.Case
  doctest Summarizer

  test "greets the world" do
    assert Summarizer.hello() == :world
  end
end
