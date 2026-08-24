defmodule Stackbox.TokenCrypto do
  @moduledoc """
  Fernet-compatible symmetric encryption for tokens stored at rest (e.g.
  `github_accounts.access_token_encrypted`).

  Wire format (matches the `cryptography` Python library's Fernet spec):
  version(1) || timestamp(8, big-endian) || iv(16) || ciphertext(N) || hmac(32),
  base64url-encoded. The signing/encryption keys are derived by splitting the
  base64url-decoded 32-byte Fernet key in half: first 16 bytes sign (HMAC-SHA256),
  last 16 bytes encrypt (AES-128-CBC). No ttl/expiry is enforced on decrypt, to
  match the Python side's `Fernet.decrypt(token)` call (no ttl argument).
  """

  alias Stackbox.Settings

  @version <<0x80>>

  def encrypt_token(plaintext) when is_binary(plaintext) do
    {signing_key, encryption_key} = keys()
    iv = :crypto.strong_rand_bytes(16)
    timestamp = <<System.system_time(:second)::unsigned-big-64>>
    padded = pkcs7_pad(plaintext, 16)
    ciphertext = :crypto.crypto_one_time(:aes_128_cbc, encryption_key, iv, padded, true)
    payload = @version <> timestamp <> iv <> ciphertext
    hmac = :crypto.mac(:hmac, :sha256, signing_key, payload)
    Base.url_encode64(payload <> hmac)
  end

  def decrypt_token(token) when is_binary(token) do
    {signing_key, encryption_key} = keys()

    with {:ok, data} <- Base.url_decode64(token),
         true <- byte_size(data) >= 1 + 8 + 16 + 32,
         <<@version, _timestamp::binary-8, iv::binary-16, rest::binary>> <- data,
         ciphertext_len = byte_size(rest) - 32,
         true <- ciphertext_len >= 0,
         <<ciphertext::binary-size(ciphertext_len), hmac::binary-32>> <- rest,
         payload = binary_part(data, 0, byte_size(data) - 32),
         expected_hmac = :crypto.mac(:hmac, :sha256, signing_key, payload),
         true <- Plug.Crypto.secure_compare(hmac, expected_hmac) do
      padded = :crypto.crypto_one_time(:aes_128_cbc, encryption_key, iv, ciphertext, false)
      {:ok, pkcs7_unpad(padded)}
    else
      _ -> {:error, :invalid_token}
    end
  end

  defp keys do
    key = Settings.get(:token_encryption_key)

    if key in [nil, ""] do
      raise "token_encryption_key is not configured"
    end

    <<signing_key::binary-16, encryption_key::binary-16>> = Base.url_decode64!(key)
    {signing_key, encryption_key}
  end

  defp pkcs7_pad(data, block_size) do
    pad_len = block_size - rem(byte_size(data), block_size)
    data <> :binary.copy(<<pad_len>>, pad_len)
  end

  defp pkcs7_unpad(data) do
    pad_len = :binary.last(data)
    binary_part(data, 0, byte_size(data) - pad_len)
  end
end
