package com.molayo.vendingkiosk;

import java.util.HashSet;
import java.util.Set;

/** No physical-device API is implemented in this milestone. */
public final class VendController {
    public enum Status { IDLE, AWAITING_PAYMENT, READY, DISPENSING, COMPLETE, FAILED }
    public interface Dispenser { boolean dispense(String slot, String orderId); }
    public interface PaymentVerifier { boolean isSettled(String orderId); }

    private final Dispenser dispenser;
    private final PaymentVerifier payments;
    private final Set<String> attempted = new HashSet<>();
    private Status status = Status.IDLE;
    private String orderId;
    private String slot;

    public VendController(Dispenser dispenser, PaymentVerifier payments) {
        this.dispenser = dispenser;
        this.payments = payments;
    }

    public synchronized void start(String nextOrderId, String nextSlot) {
        if (status == Status.AWAITING_PAYMENT || status == Status.READY || status == Status.DISPENSING)
            throw new IllegalStateException("Order already in progress");
        if (nextOrderId == null || nextOrderId.isEmpty() || nextSlot == null || nextSlot.isEmpty())
            throw new IllegalArgumentException("Order ID and slot are required");
        if (attempted.contains(nextOrderId)) throw new IllegalArgumentException("Order ID already used");
        this.orderId = nextOrderId;
        this.slot = nextSlot;
        status = Status.AWAITING_PAYMENT;
    }

    public synchronized Status vendIfPaid() {
        if (status != Status.AWAITING_PAYMENT) throw new IllegalStateException("Invalid order state");
        if (!payments.isSettled(orderId)) return status;
        status = Status.READY;
        attempted.add(orderId); // Never retry an uncertain physical vend automatically.
        status = Status.DISPENSING;
        try {
            status = dispenser.dispense(slot, orderId) ? Status.COMPLETE : Status.FAILED;
        } catch (Exception ex) {
            status = Status.FAILED;
        }
        return status;
    }

    public synchronized Status getStatus() { return status; }
}
