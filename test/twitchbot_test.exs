defmodule TwitchbotTest do
  use ExUnit.Case, async: false

  import Mock

  # def exIrcClientMock do
  #   [add_handler: fn() -> nil end]
  # end

  # def exIrcMock do
  #   [
  #     start_client!: fn() ->
  #       {
  #         :ok,
  #         exIrcClientMock
  #       }
  #     end
  #   ]
  # end

  test "application should start" do
    # with_mock ExIrc, exIrcMock do
      {result, _} = Twitchbot.start(:normal, [])
      assert result == :ok
    # end
  end
end
