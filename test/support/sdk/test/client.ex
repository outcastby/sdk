defmodule Sdk.Test.Client do
  use Sdk.BaseClient, endpoints: Map.keys(Sdk.Test.Config.data().endpoints)
end
