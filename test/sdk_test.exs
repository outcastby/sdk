defmodule SdkTest do
  use ExUnit.Case
  doctest Sdk

  test "greets the world" do
    assert Sdk.hello() == :world
  end
end
