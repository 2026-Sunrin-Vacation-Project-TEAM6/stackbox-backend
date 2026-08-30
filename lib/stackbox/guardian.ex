defmodule Stackbox.Guardian do
  @moduledoc false
  use Guardian, otp_app: :stackbox

  alias Stackbox.Accounts

  @oauth_state_purpose "github_oauth_state"

  @impl true
  def subject_for_token(%{id: id}, _claims), do: {:ok, to_string(id)}
  def subject_for_token(_resource, _claims), do: {:error, :invalid_resource}

  @impl true
  def resource_from_claims(%{"sub" => id}) do
    case Accounts.get_user(id) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end

  def resource_from_claims(_claims), do: {:error, :invalid_claims}

  def hash_password(password), do: Bcrypt.hash_pwd_salt(password)

  def verify_password(password, hash), do: Bcrypt.verify_pass(password, hash)

  def create_access_token(user_id) do
    with {:ok, user} <- fetch_user(user_id),
         {:ok, token, _claims} <- encode_and_sign(user) do
      {:ok, token}
    end
  end

  def decode_token(token) do
    with {:ok, claims} <- decode_and_verify(token) do
      {:ok, claims}
    end
  end

  def create_oauth_state_token(user_id) do
    with {:ok, user} <- fetch_user(user_id),
         {:ok, token, _claims} <-
           encode_and_sign(user, %{"purpose" => @oauth_state_purpose}, ttl: {10, :minutes}) do
      {:ok, token}
    end
  end

  def decode_oauth_state_token(token) do
    with {:ok, claims} <- decode_and_verify(token),
         @oauth_state_purpose <- Map.get(claims, "purpose"),
         {sub, ""} <- Integer.parse(Map.get(claims, "sub", "")) do
      {:ok, sub}
    else
      _ -> {:error, :invalid_state_token}
    end
  end

  defp fetch_user(user_id) do
    case Accounts.get_user(user_id) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end
end
