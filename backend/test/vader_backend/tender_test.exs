defmodule VaderBackend.TenderTest do
  use ExUnit.Case, async: true
  alias VaderBackend.Tender

  setup do
    {:ok, tender} = Tender.new(500, "GHS")
    %{tender: tender}
  end

  test "Paystack only settles authenticated exact-amount success", %{tender: tender} do
    payment = %{reference: "ps-1", amount_minor: 500, currency: "GHS", status: :success, verified: true}
    assert {:ok, paid} = Tender.paystack(tender, payment)
    assert Tender.ready?(paid)
    assert {:ok, ^paid} = Tender.paystack(paid, payment)
    assert {:error, :amount_mismatch} = Tender.paystack(tender, %{payment | amount_minor: 499})
    assert {:error, :currency_mismatch} = Tender.paystack(tender, %{payment | currency: "USD"})
    assert {:error, :payment_not_authorized} = Tender.paystack(tender, Map.delete(payment, :verified))
    assert {:error, :payment_not_authorized} = Tender.paystack(tender, %{payment | status: :pending})
  end

  test "coin and note credits combine; duplicate hardware IDs cannot double-count", %{tender: tender} do
    coin = %{event_id: "mdb-1", kind: :coin, amount_minor: 200, authenticated: true}
    note = %{event_id: "mdb-2", kind: :note, amount_minor: 300, authenticated: true}
    assert {:ok, after_coin} = Tender.cash(tender, coin)
    refute Tender.ready?(after_coin)
    assert {:ok, ^after_coin} = Tender.cash(after_coin, coin)
    assert {:ok, settled} = Tender.cash(after_coin, note)
    assert settled.credited_minor == 500
    assert Tender.ready?(settled)
    assert {:error, :cash_event_not_authorized} = Tender.cash(tender, Map.delete(coin, :authenticated))
    assert {:error, :payment_not_authorized} = Tender.paystack(settled, %{})
  end

  test "overpayment blocks vending until change confirmed", %{tender: tender} do
    assert {:ok, overpaid} = Tender.cash(tender,
      %{event_id: "mdb-3", kind: :note, amount_minor: 1000, authenticated: true})
    refute Tender.ready?(overpaid)
    assert {:error, :change_mismatch} = Tender.confirm_change(overpaid, 400)
    assert {:ok, settled} = Tender.confirm_change(overpaid, 500)
    assert Tender.ready?(settled)
  end

  test "invalid tender and fabricated events are rejected" do
    assert {:error, :invalid_tender} = Tender.new(0, "GHS")
    {:ok, tender} = Tender.new(500, "GHS")
    assert {:error, :cash_event_not_authorized} = Tender.cash(tender,
      %{event_id: "x", kind: :note, amount_minor: -1, authenticated: true})
  end
end
