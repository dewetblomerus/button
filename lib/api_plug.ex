defmodule ApiPlug do
  import Plug.Conn

  def init(options), do: options

  def call(%Plug.Conn{request_path: "/knox/knocked"} = conn, _opts) do
    message = "Knox Knocked" |> dbg()

    Pushover.send_message(message, priority: 0)
    respond(conn, message)
  end

  def call(%Plug.Conn{request_path: "/knox/emergency"} = conn, _opts) do
    message = "Knox Pressed Emergency Button" |> dbg()

    Pushover.send_message(
      message,
      expire: 10000,
      priority: 2,
      retry: 30
    )

    respond(conn, message)
  end

  def call(%Plug.Conn{request_path: "/favicon.ico"} = conn, _opts) do
    respond(conn, "favicon.ico")
  end

  def call(%Plug.Conn{request_path: fallback_request_path} = conn, _opts) do
    message = "Unsupported Request Path: #{fallback_request_path}" |> dbg()
    respond(conn, message)
  end

  defp respond(conn, message) do
    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(200, message)
    |> halt()
  end
end

defmodule Pushover do
  def send_message(message, opts \\ []) do
    params =
      %{
        token: System.fetch_env!("PUSHOVER_TOKEN"),
        user: System.fetch_env!("PUSHOVER_USER"),
        message: message,
        priority: Keyword.get(opts, :priority, 0),
        retry: Keyword.get(opts, :retry, 30),
        expire: Keyword.get(opts, :expire, 10000),
        title: Keyword.get(opts, :title),
        device: Keyword.get(opts, :device)
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    Req.post!("https://api.pushover.net/1/messages.json", json: params).body
    |> dbg()
  end
end
