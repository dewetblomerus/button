Mix.install([
  {:bandit, "~> 1.6"},
  {:req, "~> 0.5.8"}
])

defmodule ApiPlug do
  import Plug.Conn

  def init(options), do: options

  def call(%Plug.Conn{request_path: request_path} = conn, _opts) do
    message_body = RequestHandler.call(request_path)

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, message_body)
    |> halt()
  end
end

defmodule RequestHandler do
  @config %{
    "/knox/knocked" => %{
      message: "Knox Knocked",
      priority: 0
    },
    "/knox/emergency" => %{
      message: "Knox Pressed Emergency Button",
      priority: 2,
      retry: 30,
      expire: 10000
    }
  }
  def call("/favicon.ico"), do: "favicon.ico"

  def call(request_path) do
    message_body =
      case Map.get(@config, request_path) do
        %{} = message_params ->
          Pushover.send_message(message_params)
          message_params.message

        _ ->
          "Unsupported Request Path: #{request_path}" |> dbg()
      end

    message_body
  end
end

defmodule Pushover do
  def send_message(message_params) do
    params =
      %{
        token: System.fetch_env!("PUSHOVER_TOKEN"),
        user: System.fetch_env!("PUSHOVER_USER"),
        message: Map.fetch!(message_params, :message),
        priority: Map.fetch!(message_params, :priority),
        retry: Map.get(message_params, :retry, nil),
        expire: Map.get(message_params, :expire, nil)
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    dbg(params)

    "brhttps://api.pushover.net/1/messages.json"
    |> Req.post!(json: params).body
    |> dbg()
  end
end

children = [
  {Bandit, plug: ApiPlug, port: System.fetch_env!("PORT")}
]

opts = [strategy: :one_for_one, name: Button.Supervisor]
{:ok, _} = Supervisor.start_link(children, opts)

Process.sleep(:infinity)
