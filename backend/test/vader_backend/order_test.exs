defmodule VaderBackend.OrderTest do
  use ExUnit.Case, async: true
  alias VaderBackend.Order

  @valid %{id: "order-123", amount_minor: 1250, currency: "GHS", slots: ["A1", "B2"]}
  @payment %{reference: "verified-pay-9", amount_minor: 1250, currency: "GHS", verified: true}
  @safe %{temperature_safe: true, door_closed: true, stock_reserved: true}

  defp new_order do
    {:ok, order} = Order.new(@valid)
    order
  end

  test "rejects invalid order amounts or slots" do
    assert {:error, :invalid_order} = Order.new(%{@valid | amount_minor: 0})
    assert {:error, :invalid_order} = Order.new(%{@valid | slots: []})
    assert {:error, :invalid_slots} = Order.new(%{@valid | slots: [nil]})
  end

  test "requires verified, matching payment" do
    order = new_order()
    assert {:error, :payment_not_authorized} = Order.confirm_payment(order, %{@payment | verified: false})
    assert {:error, :amount_mismatch} = Order.confirm_payment(order, %{@payment | amount_minor: 1000})
    assert {:error, :currency_mismatch} = Order.confirm_payment(order, %{@payment | currency: "USD"})
    assert {:ok, paid} = Order.confirm_payment(order, @payment)
    assert paid.status == :paid
    assert {:ok, ^paid} = Order.confirm_payment(paid, @payment)
    assert {:error, :payment_not_authorized} = Order.confirm_payment(paid, %{@payment | reference: "different"})
  end

  test "cannot dispense before payment" do
    assert {:error, :invalid_transition} = Order.authorize_dispense(new_order(), @safe)
  end

  test "refrigeration, door and inventory conditions gate dispensing" do
    {:ok, paid} = Order.confirm_payment(new_order(), @payment)
    for key <- [:temperature_safe, :door_closed, :stock_reserved] do
      assert {:error, :machine_not_safe} = Order.authorize_dispense(paid, Map.put(@safe, key, false))
    end
    assert {:ok, dispensing} = Order.authorize_dispense(paid, @safe)
    assert dispensing.attempt_id == "order-123:vend:1"
    assert {:error, :invalid_transition} = Order.authorize_dispense(dispensing, @safe)
  end

  test "only verified delivery completes an order" do
    {:ok, paid} = Order.confirm_payment(new_order(), @payment)
    {:ok, dispensing} = Order.authorize_dispense(paid, @safe)
    assert {:error, :invalid_transition} = Order.record_delivery(paid, :confirmed)
    assert {:ok, completed} = Order.record_delivery(dispensing, :confirmed)
    assert completed.status == :complete
    assert {:error, :invalid_transition} = Order.record_delivery(completed, :confirmed)
  end

  test "uncertain hardware outcomes require review, never automatic retry" do
    {:ok, paid} = Order.confirm_payment(new_order(), @payment)
    {:ok, dispensing} = Order.authorize_dispense(paid, @safe)
    assert {:ok, uncertain} = Order.record_delivery(dispensing, :timeout)
    assert uncertain.status == :needs_review
    assert uncertain.failure_reason == :timeout
    assert {:error, :invalid_transition} = Order.authorize_dispense(uncertain, @safe)
  end

  test "only unpaid orders can be cancelled" do
    assert {:ok, cancelled} = Order.cancel(new_order())
    assert cancelled.status == :cancelled
    assert {:error, :invalid_transition} = Order.authorize_dispense(cancelled, @safe)
    {:ok, paid} = Order.confirm_payment(new_order(), @payment)
    assert {:error, :invalid_transition} = Order.cancel(paid)
  end
end
