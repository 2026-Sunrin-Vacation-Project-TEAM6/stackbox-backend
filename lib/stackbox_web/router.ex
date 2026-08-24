defmodule StackboxWeb.Router do
  use Phoenix.Router, helpers: false

  import Plug.Conn
  import Phoenix.Controller

  pipeline :api do
    plug(:accepts, ["json"])
  end

  pipeline :auth do
    plug(StackboxWeb.Plugs.AuthPlug)
  end

  scope "/", StackboxWeb do
    pipe_through(:api)

    get("/health", HealthController, :show)
  end

  scope "/auth", StackboxWeb do
    pipe_through(:api)

    post("/register", AuthController, :register)
    post("/login", AuthController, :login)
    post("/refresh", AuthController, :refresh)
    post("/logout", AuthController, :logout)
  end

  scope "/users", StackboxWeb do
    pipe_through([:api, :auth])

    get("/:id", UserController, :show)
    patch("/:id", UserController, :update)
    delete("/:id", UserController, :delete)
  end

  scope "/workspaces", StackboxWeb do
    pipe_through([:api, :auth])

    post("/", WorkspaceController, :create)
    get("/", WorkspaceController, :index)
    get("/:id", WorkspaceController, :show)
    patch("/:id", WorkspaceController, :update)
    delete("/:id", WorkspaceController, :delete)

    post("/:id/members", WorkspaceController, :add_member)
    get("/:id/members", WorkspaceController, :list_members)
    patch("/:id/members/:user_id", WorkspaceController, :update_member)
    delete("/:id/members/:user_id", WorkspaceController, :remove_member)
  end

  scope "/stack-boxes", StackboxWeb do
    pipe_through([:api, :auth])

    post("/", StackBoxController, :create)
    get("/", StackBoxController, :index)
    get("/:id", StackBoxController, :show)
    patch("/:id", StackBoxController, :update)
    delete("/:id", StackBoxController, :delete)

    get("/:id/snapshot", StackBoxController, :get_snapshot)
    put("/:id/snapshot", StackBoxController, :upsert_snapshot)
    get("/:id/updates", StackBoxController, :list_doc_updates)
    get("/:id/presence", StackBoxController, :list_presence)
  end

  scope "/stack-boxes/:stack_box_id/blocks", StackboxWeb do
    pipe_through([:api, :auth])

    get("/", BlockController, :index)
    post("/", BlockController, :create)
    patch("/:id", BlockController, :update)
    delete("/:id", BlockController, :delete)
    post("/reorder", BlockController, :reorder)
  end

  scope "/blocks", StackboxWeb do
    pipe_through([:api, :auth])

    post("/:id/run", CodeExecController, :run_block)
    get("/:id/runs", CodeExecController, :list_runs)
  end

  scope "/github", StackboxWeb do
    pipe_through([:api, :auth])

    get("/oauth/login", GithubController, :oauth_login)
    get("/oauth/callback", GithubController, :oauth_callback)
    get("/account", GithubController, :get_account)
    get("/repos", GithubController, :list_repos)
    get("/contents", GithubController, :list_contents)
    post("/import", GithubController, :import_files)
  end

  scope "/ai", StackboxWeb do
    pipe_through([:api, :auth])

    post("/summarize", AIController, :summarize)
    post("/fix-code", AIController, :fix_code)
    post("/edit-text", AIController, :edit_text)
    post("/draft", AIController, :draft)
    post("/chat", AIController, :chat)
    post("/doc-to-ppt", AIController, :doc_to_ppt)
  end

  scope "/reactions", StackboxWeb do
    pipe_through([:api, :auth])

    get("/catalog", ReactionController, :catalog)
    get("/", ReactionController, :index)
    post("/", ReactionController, :create)
    delete("/:id", ReactionController, :delete)
  end
end
