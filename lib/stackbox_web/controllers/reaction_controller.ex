defmodule StackboxWeb.ReactionController do
  @moduledoc """
  Mirrors `backend/app/routers/reactions.py` and `backend/app/emoji_catalog.py`.

  The Python routes nest reactions under `/stack-boxes/{id}/reactions`; this
  router instead scaffolds a flat `/reactions` resource, so `stack_box_id` is
  taken from the query string (`index`) or JSON body (`create`) instead of
  the path.
  """

  use StackboxWeb, :controller

  alias Stackbox.Authorization
  alias Stackbox.Reactions
  alias Stackbox.StackBoxes

  action_fallback StackboxWeb.FallbackController

  @emoji_catalog [
    %{code: "jaemin_thumbsup", label: "최고예요", image_path: "/emoji/재민티콘/thumbsup.png"},
    %{code: "jaemin_heart", label: "사랑해요", image_path: "/emoji/재민티콘/heart.png"},
    %{code: "jaemin_laugh", label: "웃겨요", image_path: "/emoji/재민티콘/laugh.png"},
    %{code: "jaemin_wow", label: "놀라워요", image_path: "/emoji/재민티콘/wow.png"},
    %{code: "jaemin_sad", label: "슬퍼요", image_path: "/emoji/재민티콘/sad.png"},
    %{code: "jaemin_fire", label: "대박이에요", image_path: "/emoji/재민티콘/fire.png"},
    %{code: "jaemin_clap", label: "박수쳐요", image_path: "/emoji/재민티콘/clap.png"},
    %{code: "jaemin_think", label: "고민중이에요", image_path: "/emoji/재민티콘/think.png"}
  ]
  @valid_emoji_codes MapSet.new(@emoji_catalog, & &1.code)

  def catalog(conn, _params), do: json(conn, @emoji_catalog)

  def index(conn, %{"stack_box_id" => stack_box_id}) do
    with {:ok, stack_box} <- fetch_stack_box(stack_box_id),
         {:ok, _role} <- require_role(stack_box.workspace_id, conn.assigns.current_user, :viewer) do
      reactions = Reactions.list_reactions(stack_box.id)
      json(conn, Enum.map(reactions, &reaction_json/1))
    end
  end

  def index(_conn, _params), do: {:error, :bad_request, "stack_box_id is required"}

  def create(conn, %{"stack_box_id" => stack_box_id, "emoji_code" => emoji_code}) do
    current_user = conn.assigns.current_user

    with {:ok, stack_box} <- fetch_stack_box(stack_box_id),
         {:ok, _role} <- require_role(stack_box.workspace_id, current_user, :viewer),
         :ok <- validate_emoji(emoji_code),
         {:ok, reaction} <-
           Reactions.add_reaction(%{
             stack_box_id: stack_box.id,
             user_id: current_user.id,
             emoji_code: emoji_code
           }) do
      conn |> put_status(:created) |> json(reaction_json(reaction))
    else
      {:error, %Ecto.Changeset{errors: errors}} ->
        if Keyword.has_key?(errors, :stack_box_id) or has_unique_error?(errors) do
          {:error, :conflict, "Reaction already exists"}
        else
          {:error, :bad_request, "Invalid reaction"}
        end

      other ->
        other
    end
  end

  def create(_conn, _params),
    do: {:error, :bad_request, "stack_box_id and emoji_code are required"}

  def delete(conn, %{"id" => id}) do
    current_user = conn.assigns.current_user

    with {:ok, int_id} <- parse_id(id),
         reaction when not is_nil(reaction) <- Reactions.get_reaction_by_id(int_id) do
      if reaction.user_id == current_user.id do
        {:ok, _} = Reactions.remove_reaction(reaction)
        send_resp(conn, :no_content, "")
      else
        {:error, :forbidden, "Not your reaction"}
      end
    else
      nil -> {:error, :not_found, "Reaction not found"}
      {:error, :not_found, _} = error -> error
    end
  end

  defp has_unique_error?(errors) do
    Enum.any?(errors, fn {_field, {_msg, opts}} -> Keyword.get(opts, :constraint) == :unique end)
  end

  defp validate_emoji(emoji_code) do
    if MapSet.member?(@valid_emoji_codes, emoji_code) do
      :ok
    else
      {:error, :bad_request, "Unknown emoji code"}
    end
  end

  defp fetch_stack_box(id) do
    with {:ok, int_id} <- parse_id(id) do
      case StackBoxes.get_stack_box(int_id) do
        nil -> {:error, :not_found, "StackBox not found"}
        stack_box -> {:ok, stack_box}
      end
    end
  end

  defp require_role(workspace_id, user, minimum) do
    case Authorization.require_workspace_role(workspace_id, user, minimum) do
      {:ok, role} -> {:ok, role}
      {:error, :forbidden} -> {:error, :forbidden, "Insufficient workspace permissions"}
    end
  end

  defp parse_id(id) when is_integer(id), do: {:ok, id}

  defp parse_id(id) when is_binary(id) do
    case Integer.parse(id) do
      {int_id, ""} -> {:ok, int_id}
      _ -> {:error, :not_found, "Not found"}
    end
  end

  defp reaction_json(reaction) do
    %{
      id: reaction.id,
      stack_box_id: reaction.stack_box_id,
      user_id: reaction.user_id,
      emoji_code: reaction.emoji_code,
      created_at: reaction.created_at
    }
  end
end
