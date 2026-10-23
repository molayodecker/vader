defmodule VaderBackend.Order do
  @moduledoc """
  A pure, immutable order state machine. Payment verification, persistence,
  hardware commands, and refrigeration telemetry belong to trusted adapters.
  No function in this module sends money or triggers a motor.
  """

  @enforce_keys [:id, :amount_minor, :currency, :slots]
  defstruct [:id, :amount_minor, :currency, :slots, :payment_reference,
             :attempt_id, :failure_reason, status: :awaiting_payment]

  @type status :: :awaiting_payment | :paid | :dispensing | :complete |
                  :needs_review | :cancelled

  @spec new(map()) :: {:ok, %__MODULE__{}} | {:error, atom()}
  def new(%{id: id, amount_minor: amount, currency: currency, slots: slots})
      when is_binary(id) and byte_size(id) > 0 and is_integer(amount) and amount > 0 and
             currency in ["GHS", "USD"] and is_list(slots) and slots != [] do
    if Enum.all?(slots, &(is_binary(&1) and byte_size(&1) > 0)) do
      {:ok, %__MODULE__{id: id, amount_minor: amount, currency: currency, slots: slots}}
    else
      {:error, :invalid_slots}
    end
  end

  def new(_), do: {:error, :invalid_order}

  @doc "Called only after a trusted payment adapter verifies provider authenticity and settlement."
  @spec confirm_payment(%__MODULE__{}, map()) :: {:ok, %__MODULE__{}} | {:error, atom()}
  def confirm_payment(%__MODULE__{status: :awaiting_payment} = order,
        %{reference: ref, amount_minor: amount, currency: currency, verified: true})
      when is_binary(ref) and byte_size(ref) > 0 do
    cond do
      amount != order.amount_minor -> {:error, :amount_mismatch}
      currency != order.currency -> {:error, :currency_mismatch}
      true -> {:ok, %{order | status: :paid, payment_reference: ref}}
    end
  end

  def confirm_payment(%__MODULE__{payment_reference: ref} = order,
        %{reference: ref, amount_minor: amount, currency: currency, verified: true})
      when not is_nil(ref) do
    if amount == order.amount_minor and currency == order.currency,
      do: {:ok, order}, else: {:error, :payment_mismatch}
  end

  def confirm_payment(_, _), do: {:error, :payment_not_authorized}

  @doc "Returns an attempt identity to persist atomically before hardware dispatch."
  @spec authorize_dispense(%__MODULE__{}, map()) :: {:ok, %__MODULE__{}} | {:error, atom()}
  def authorize_dispense(%__MODULE__{status: :paid} = order,
        %{temperature_safe: true, door_closed: true, stock_reserved: true}) do
    {:ok, %{order | status: :dispensing, attempt_id: order.id <> ":vend:1"}}
  end

  def authorize_dispense(%__MODULE__{status: :paid}, _), do: {:error, :machine_not_safe}
  def authorize_dispense(_, _), do: {:error, :invalid_transition}

  @doc "A transport acknowledgment is not proof of delivery: only verified delivery can complete."
  @spec record_delivery(%__MODULE__{}, atom()) :: {:ok, %__MODULE__{}} | {:error, atom()}
  def record_delivery(%__MODULE__{status: :dispensing} = order, :confirmed),
    do: {:ok, %{order | status: :complete}}

  def record_delivery(%__MODULE__{status: :dispensing} = order, reason)
      when reason in [:timeout, :sensor_failure, :motor_fault] do
    {:ok, %{order | status: :needs_review, failure_reason: reason}}
  end

  def record_delivery(_, _), do: {:error, :invalid_transition}

  @spec cancel(%__MODULE__{}) :: {:ok, %__MODULE__{}} | {:error, atom()}
  def cancel(%__MODULE__{status: :awaiting_payment} = order),
    do: {:ok, %{order | status: :cancelled}}

  def cancel(_), do: {:error, :invalid_transition}
end
