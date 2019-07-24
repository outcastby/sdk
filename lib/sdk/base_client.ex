defmodule Sdk.BaseClient do
  use HTTPoison.Base
  require IEx
  require Logger

  @timeout 20_000
  @base_headers ["Content-Type": "application/json"]

  defmacro __using__(endpoints: endpoints) do
    quote bind_quoted: [endpoints: endpoints] do
      endpoints
      |> Enum.each(fn event ->
        def unquote(event)(request \\ nil) do
          {method_name, _} = __ENV__.function
          __MODULE__.method_missing(method_name, request)
        end
      end)

      @doc """
      Base url preparing
      Feel free to override this behaviour like you wish
      """
      def prepare_url(url), do: Sdk.BaseClient.prepare_url(__MODULE__, url)

      def method_missing(method_name, request),
        do: Sdk.BaseClient.method_missing(__MODULE__, method_name, request)

      @doc """
      Returns tuple of parameters.
      """
      def perform(method, url, payload \\ %{}, headers \\ [], options \\ %{}),
        do: Sdk.BaseClient.perform(__MODULE__, method, url, payload, headers, options)

      def gql(query, variables \\ nil), do: Sdk.BaseClient.gql(__MODULE__, query, variables)

      def handle_response(response, status),
        do: Sdk.BaseClient.handle_response(response, status)

      def config, do: Sdk.BaseClient.config(__MODULE__)

      def name, do: Sdk.BaseClient.name(__MODULE__)

      def prepare_headers(headers), do: Sdk.BaseClient.prepare_headers(headers)
      def prepare_options(options), do: Sdk.BaseClient.prepare_options(options)

      def prepare_payload(payload, headers),
        do: Sdk.BaseClient.prepare_payload(payload, headers)

      defoverridable prepare_headers: 1, handle_response: 2, prepare_options: 1
    end
  end

  def prepare_url(module, url), do: config(module).base_url <> url

  def method_missing(module, method_name, %Sdk.Request{
        headers: headers,
        payload: payload,
        options: options
      }),
      do: call_missing(module, method_name, payload, headers, options)

  def method_missing(module, method_name, nil),
    do: call_missing(module, method_name, %{}, [], %{})

  @doc """
  Returns tuple of parameters.
  """
  def call_missing(module, method_name, payload, headers, options) do
    %{endpoints: %{^method_name => %{url: url, type: type}}} = config(module)
    url = if is_binary(url), do: url, else: url.(options.url_params)
    perform(module, type, url, payload, headers, options)
  end

  def perform(module, method, url, payload, headers, options) do
    headers = module.prepare_headers(headers)
    url = apply(module, :prepare_url, get_url_params(module, url, options))
    options = module.prepare_options(options)

    Logger.metadata(sdk: name(module), method: method, url: process_url(url))

    Logger.info("request: #{inspect(payload)}, headers: #{inspect(headers)}")

    case perform_request(method, url, payload, headers, options) do
      {:error, resp} ->
        handle_error("response: #{inspect(resp)}")

      {:ok, %{body: body, status_code: status_code} = resp} ->
        Logger.info("response: #{inspect(resp)}")

        cond do
          status_code >= 400 -> module.handle_response(body, :error)
          true -> module.handle_response(body, :ok)
        end
    end
  end

  defp get_url_params(module, url, options) do
    case :erlang.function_exported(module, :prepare_url, 2) do
      true -> [url, options]
      _ -> [url]
    end
  end

  defp perform_request(:get, url, payload, headers, options),
    do: __MODULE__.get(url, headers, [params: payload] |> Keyword.merge(options))

  defp perform_request(method, url, payload, headers, options),
    do:
      apply(__MODULE__, method, [
        url,
        prepare_payload(payload, headers),
        headers,
        options
      ])

  def prepare_options(options),
    do: %{recv_timeout: @timeout, timeout: @timeout} |> Map.merge(options) |> Enum.into([])

  def gql(module, query, variables) do
    url = config(module).base_url <> config(module).gql_path
    Logger.metadata(sdk: name(module), url: url)

    Neuron.Config.set(url: url)
    Neuron.Config.set(connection_opts: [recv_timeout: @timeout, timeout: @timeout])

    case Neuron.query(query, variables) do
      {:error, resp} ->
        handle_error("query: #{query}, response: #{inspect(resp)}")

      {:ok, %Neuron.Response{body: body} = resp} ->
        Logger.info("query: #{query}, response: #{inspect(resp)}")
        {:ok, body["data"]}
    end
  end

  def handle_response(response, status) do
    try do
      {status, response |> Poison.decode!()}
    rescue
      _ -> {status, response}
    end
  end

  def handle_error(message, metadata \\ []) do
    Logger.error(message, metadata)
    {:error, message}
  end

  def config(module) do
    modules = module |> to_string |> String.split(".")
    config_module_name = (Enum.drop(modules, -1) ++ ["Config"]) |> Enum.join(".")
    String.to_atom(config_module_name).data
  end

  def name(module), do: config(module).sdk_name

  def prepare_headers(headers) when is_map(headers),
    do: headers |> Enum.into([]) |> prepare_headers()

  def prepare_headers(headers), do: @base_headers ++ headers

  def prepare_payload(payload, [{_, content_type} | _])
      when content_type == "application/x-www-form-urlencoded",
      do: {:form, Enum.to_list(payload)}

  def prepare_payload(payload, _), do: Poison.encode!(payload)
end
