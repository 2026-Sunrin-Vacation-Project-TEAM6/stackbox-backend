defmodule StackboxWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :stackbox

  @session_options [
    store: :cookie,
    key: "_stackbox_key",
    signing_salt: "stackboxsign",
    same_site: "Lax"
  ]

  socket("/socket", StackboxWeb.UserSocket,
    websocket: true,
    longpoll: false
  )

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Phoenix.json_library()
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)
  plug(Plug.Session, @session_options)

  plug(CORSPlug,
    origin: [
      "http://localhost",
      "http://127.0.0.1",
      "http://localhost:3000",
      "http://127.0.0.1:3000",
      "http://localhost:3002",
      "http://127.0.0.1:3002",
      "http://localhost:8000",
      "http://127.0.0.1:8000"
    ],
    credentials: true,
    headers: ["*"],
    methods: ["*"]
  )

  plug(StackboxWeb.Router)
end
