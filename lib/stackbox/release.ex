defmodule Stackbox.Release do
  @moduledoc """
  Tasks run in a release before the app starts, coordinated by
  bin/start_migrate — currently Ecto migrations. Release commands run in the
  `console` (non-app) context, so we share a Repo connection explicitly and
  shut it down when the run finishes so the boot process can start cleanly.
  """
  @app :stackbox

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    Application.load(@app)
  end
end