defmodule Sdk.BaseClient do
  defmacro __using__(endpoints: endpoints) do
    quote bind_quoted: [endpoints: endpoints] do
      use HTTPoison.Base
      require IEx
      require Logger

      endpoints
      |> Enum.each(fn event ->
        def unquote(event)(x \\ nil) do
          {method_name, _} = __ENV__.function
          __MODULE__.method_missing(method_name, x)
        end
      end)

      @doc """
      Base url preparing
      Feel free to override this behaviour like you wish
      See example login_phoenix/lib/login_phoenix/core/sdk/shard/client.ex
      """
      @spec prepare_url(url :: String.t()) :: String.t()
      def prepare_url(url), do: config().base_url <> url

      @doc """
      Returns tuple of parametrs.
      """
      @spec method_missing(method_name :: Atom, List.new(%Sdk.Request{})) :: %{}
      def method_missing(method_name, %Sdk.Request{headers: headers, payload: payload, options: options}) do
        call_missing(method_name, payload, headers, options)
      end

      def method_missing(method_name, nil) do
        call_missing(method_name, %{}, [], %{})
      end

      @doc """
      Returns tuple of parametrs.
      """
      @spec call_missing(method_name :: Atom, payload :: %{}, headers :: [], options :: %{}) :: %{}
      def call_missing(method_name, payload, headers, options) do
        endpoint = config().endpoints[method_name]

        cond do
          endpoint ->
            url = if is_binary(endpoint.url), do: endpoint.url, else: endpoint.url.(options.url_params)
            perform(endpoint.type, url, payload, headers, options)

          true ->
            handle_error("Endpoint for #{inspect(method_name)} is not found")
        end
      end

      @doc """
      Returns tuple of parametrs.
      """
      @spec perform(method :: String.t(), url :: String.t(), payload :: %{}, headers :: [], options :: %{}) :: %{}
      def perform(method, url, payload \\ %{}, headers \\ [], options \\ %{}) do
        headers = prepare_headers(headers)

        url =
          case :erlang.function_exported(__MODULE__, :prepare_url, 2) do
            true -> apply(__MODULE__, :prepare_url, [url, options])
            _ -> apply(__MODULE__, :prepare_url, [url])
          end

        Logger.info(
          "[#{name()}] [#{method}] #{process_url(url)} -> request: #{inspect(payload)}, headers: #{inspect(headers)}"
        )

        {status, resp} =
          case method do
            :post -> post(url, prepare_payload(payload, headers), headers, recv_timeout: 20000)
            :put -> put(url, prepare_payload(payload, headers), headers, recv_timeout: 20000)
            :get -> get(url, headers, params: payload, recv_timeout: 20000)
          end

        case status do
          :error ->
            handle_error("[#{name()}] [#{method}] #{process_url(url)} -> response: #{inspect(resp)}")

          :ok ->
            Logger.info("[#{name()}] [#{method}] #{process_url(url)} -> response: #{inspect(resp)}")

            cond do
              Enum.member?([4.0, 5.0], Float.floor(resp.status_code / 100)) -> handle_response(resp.body, :error)
              true -> handle_response(resp.body, :ok)
            end
        end
      end

      def gql(query, variables \\ nil) do
        Neuron.Config.set(url: config().base_url <> config().gql_path)
        {:ok, %Neuron.Response{body: body}} = Neuron.query(query, variables)
        {:ok, body["data"]}
      end

      def handle_response(response, status) do
        try do
          {status, response |> Poison.decode!()}
        rescue
          _ -> {status, response}
        end
      end

      def handle_error(message) do
        Logger.error(message)
        {:error, message}
      end

      def config do
        modules = __MODULE__ |> to_string |> String.split(".")
        config_module_name = (Enum.drop(modules, -1) ++ ["Config"]) |> Enum.join(".")
        String.to_existing_atom(config_module_name).data
      end

      def name, do: config().sdk_name

      @spec prepare_headers(headers :: []) :: []
      def prepare_headers(headers), do: ["Content-Type": "application/json"] ++ headers

      @spec prepare_payload(payload :: %{}, headers :: []) :: %{} | String.t()
      def prepare_payload(payload, headers) do
        {_, content_type} = headers |> List.first()

        cond do
          content_type == "application/x-www-form-urlencoded" -> {:form, Enum.to_list(payload)}
          true -> Poison.encode!(payload)
        end
      end

      defoverridable prepare_headers: 1
    end
  end
end
