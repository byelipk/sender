defmodule SenderTest do
  use ExUnit.Case
  doctest Sender

  test "sends an email" do
    assert Sender.send_email("hello@example.com") == {:ok, "email_sent"}
  end
end
