Mix.install([
  {:bandit, "~> 1.6"},
  {:req, "~> 0.5"}
])

defmodule Router do
  use Plug.Router
  plug(Plug.Logger)
  plug(:match)
  plug(:dispatch)

  get "/notify/:action" do
    response = Notify.call(action)
    send_resp(conn, response.status, response.message)
  end

  match _ do
    send_resp(conn, 404, "not found")
  end
end

defmodule Notify do
  @config %{
    "knox_knocked" => %{
      message: "Knox Knocked",
      priority: 1
    },
    "knox_emergency" => %{
      expire: 10000,
      message: "Knox Pressed Emergency Button",
      priority: 2,
      retry: 30,
      sound: "persistent"
    }
  }

  def call(action) do
    message_body =
      case Map.get(@config, action) do
        %{} = message_params ->
          Pushover.send_message(message_params)

          %{
            message: message_params.message,
            status: 200
          }

        _ ->
          %{
            message: "Unsupported Request: #{action}",
            status: 404
          }
      end

    message_body
  end
end

defmodule Pushover do
  @pushover_token System.fetch_env!("PUSHOVER_TOKEN")
  @pushover_user System.fetch_env!("PUSHOVER_USER")

  def send_message(message_params) do
    params =
      %{
        expire: Map.get(message_params, :expire, nil),
        message: Map.fetch!(message_params, :message),
        priority: Map.fetch!(message_params, :priority),
        sound: Map.get(message_params, :sound),
        retry: Map.get(message_params, :retry),
        token: @pushover_token,
        user: @pushover_user
      }
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Map.new()

    dbg(params)

    Req.post!(
      "https://api.pushover.net/1/messages.json",
      json: params
    )
  end
end

bandit = {Bandit, plug: Router, port: System.fetch_env!("PORT")}

{:ok, _} = Supervisor.start_link([bandit], strategy: :one_for_one)

Process.sleep(:infinity)
