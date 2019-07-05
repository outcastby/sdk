defmodule Sdk.Test.Config do
  def data,
    do: %{
      base_url: "http://test",
      gql_path: "/api",
      sdk_name: "TestSdk",
      endpoints: %{
        get_test: %{
          type: :get,
          url: "/get_test"
        },
        post_test: %{
          type: :post,
          url: "/post_test"
        }
      }
    }
end
