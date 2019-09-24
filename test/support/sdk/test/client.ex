defmodule SDK.Test.Client do
  use SDK.BaseClient, endpoints: Map.keys(SDK.Test.Config.data().endpoints)
end
