defmodule VaderBackend.PaystackVerification do
  @moduledoc """
  Validates a decoded Paystack `GET /transaction/verify/:reference` response
  against the server's own immutable order. This is NOT an HTTP client and
  MUST only be passed a response fetched server-to-server using the secret key.

  Never accept this map from the Android kiosk or a public API request.
  The caller persists the resulting settlement under a unique provider
  reference and must check the transaction's business ownership separately.
  """

  @spec verify(map(), map()) :: {:ok, map()} | {:error, atom()}
  def verify(%{id: order_id, amount_minor: expected_amount, currency: expected_currency,
               payment_reference: reference}, response)
      when is_binary(order_id) and is_binary(reference) and byte_size(reference) > 0 and
           is_integer(expected_amount) and expected_amount > 0 and is_binary(expected_currency) and
           is_map(response) do
    data = Map.get(response, "data")

    cond do
      Map.get(response, "status") != true -> {:error, :provider_request_failed}
      not is_map(data) -> {:error, :missing_transaction}
      Map.get(data, "reference") != reference -> {:error, :reference_mismatch}
      Map.get(data, "status") != "success" -> {:error, :not_successful}
      Map.get(data, "amount") != expected_amount -> {:error, :amount_mismatch}
      Map.get(data, "currency") != expected_currency -> {:error, :currency_mismatch}
      true -> {:ok, %{order_id: order_id, reference: reference,
                       amount_minor: expected_amount, currency: expected_currency}}
    end
  end

  def verify(_, _), do: {:error, :invalid_verification_input}
end
