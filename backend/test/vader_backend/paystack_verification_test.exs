defmodule VaderBackend.PaystackVerificationTest do
  use ExUnit.Case, async: true
  alias VaderBackend.PaystackVerification

  @order %{id: "order-1", amount_minor: 1200, currency: "GHS", payment_reference: "ps-ref-1"}
  @response %{"status" => true, "data" => %{
    "reference" => "ps-ref-1", "amount" => 1200, "currency" => "GHS", "status" => "success"}}

  test "accepts only matching successful provider verification" do
    assert {:ok, %{order_id: "order-1", reference: "ps-ref-1", amount_minor: 1200}} =
      PaystackVerification.verify(@order, @response)
  end

  test "rejects altered transaction reference and amount" do
    assert {:error, :reference_mismatch} = verify_data(%{"reference" => "someone-else"})
    assert {:error, :amount_mismatch} = verify_data(%{"amount" => 1199})
    assert {:error, :currency_mismatch} = verify_data(%{"currency" => "NGN"})
  end

  test "rejects pending, failed, malformed and provider error responses" do
    assert {:error, :not_successful} = verify_data(%{"status" => "pending"})
    assert {:error, :not_successful} = verify_data(%{"status" => "failed"})
    assert {:error, :missing_transaction} = PaystackVerification.verify(@order, %{"status" => true})
    assert {:error, :provider_request_failed} =
      PaystackVerification.verify(@order, %{"status" => false, "data" => @response["data"]})
    assert {:error, :invalid_verification_input} = PaystackVerification.verify(%{}, @response)
  end

  defp verify_data(patch) do
    response = put_in(@response, ["data"], Map.merge(@response["data"], patch))
    PaystackVerification.verify(@order, response)
  end
end
