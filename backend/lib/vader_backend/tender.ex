defmodule VaderBackend.Tender do
  @moduledoc """
  Pure tender accumulator for a single order. Hardware and Paystack adapters must
  authenticate events before passing them here. No money is collected by this module.

  Cash can combine coin and banknote credit. An excess credit requires a confirmed
  change payout or an explicit operator resolution before vending is authorized.
  """

  @enforce_keys [:amount_minor, :currency]
  defstruct [:amount_minor, :currency, :method, :paystack_reference,
             credited_minor: 0, change_paid_minor: 0, seen_events: MapSet.new()]

  def new(amount, currency) when is_integer(amount) and amount > 0 and currency in ["GHS", "USD"],
    do: {:ok, %__MODULE__{amount_minor: amount, currency: currency}}
  def new(_, _), do: {:error, :invalid_tender}

  @doc "Only call with a server-verified Paystack success response, never with client input."
  def paystack(%__MODULE__{method: nil} = tender,
        %{reference: reference, amount_minor: amount, currency: currency, status: :success, verified: true})
      when is_binary(reference) and byte_size(reference) > 0 do
    cond do
      amount != tender.amount_minor -> {:error, :amount_mismatch}
      currency != tender.currency -> {:error, :currency_mismatch}
      true -> {:ok, %{tender | method: :paystack, credited_minor: amount, paystack_reference: reference}}
    end
  end

  def paystack(%__MODULE__{method: :paystack, paystack_reference: reference} = tender,
        %{reference: reference, amount_minor: amount, currency: currency, status: :success, verified: true}) do
    if amount == tender.amount_minor and currency == tender.currency,
      do: {:ok, tender}, else: {:error, :payment_mismatch}
  end

  def paystack(_, _), do: {:error, :payment_not_authorized}

  @doc "Only call with a real, validated MDB credit report with a stable event ID."
  def cash(%__MODULE__{method: method} = tender,
        %{event_id: event_id, kind: kind, amount_minor: amount, authenticated: true})
      when method in [nil, :cash] and kind in [:coin, :note] and
           is_binary(event_id) and byte_size(event_id) > 0 and
           is_integer(amount) and amount > 0 do
    if MapSet.member?(tender.seen_events, event_id) do
      {:ok, tender}
    else
      {:ok, %{tender | method: :cash, credited_minor: tender.credited_minor + amount,
        seen_events: MapSet.put(tender.seen_events, event_id)}}
    end
  end

  def cash(_, _), do: {:error, :cash_event_not_authorized}

  @doc "Records confirmed physical change payout (not a payout request)."
  def confirm_change(%__MODULE__{method: :cash} = tender, amount)
      when is_integer(amount) and amount >= 0 do
    due = max(tender.credited_minor - tender.amount_minor, 0)
    if amount == due and tender.credited_minor >= tender.amount_minor do
      {:ok, %{tender | change_paid_minor: amount}}
    else
      {:error, :change_mismatch}
    end
  end
  def confirm_change(_, _), do: {:error, :change_not_authorized}

  def ready?(%__MODULE__{method: :paystack} = tender),
    do: tender.credited_minor == tender.amount_minor
  def ready?(%__MODULE__{method: :cash} = tender),
    do: tender.credited_minor >= tender.amount_minor and
      tender.change_paid_minor == tender.credited_minor - tender.amount_minor
  def ready?(_), do: false
end
