package com.molayo.vendingkiosk;

import java.util.HashSet;
import java.util.Set;

/** No physical-device API is implemented in this milestone. */
public final class VendController {
    public enum Status { IDLE, AWAITING_PAYMENT, READY, DISPENSING, COMPLETE, FAILED }
    public interface Dispenser { boolean dispense(String slot, String orderId); }
    public interface PaymentVerifier { boolean isSettled(String orderId); }
    /** Must persist the attempt before any hardware write. No automatic retry after ambiguity. */
    public interface AttemptJournal {
        boolean wasAttempted(String orderId);
        boolean markAttempted(String orderId);
    }

    private static final class InMemoryAttemptJournal implements AttemptJournal {
        private final Set<String> ids = new HashSet<>();
        @Override public synchronized boolean wasAttempted(String id) { return ids.contains(id); }
        @Override public synchronized boolean markAttempted(String id) { return ids.add(id); }
    }

    private final Dispenser dispenser;
    private final PaymentVerifier payments;
    private final AttemptJournal journal;
    private Status status = Status.IDLE;
    private String orderId;
    private String slot;

    public VendController(Dispenser dispenser, PaymentVerifier payments) {
        this(dispenser, payments, new InMemoryAttemptJournal());
    }

    public VendController(Dispenser dispenser, PaymentVerifier payments, AttemptJournal journal) {
        if (dispenser == null || payments == null || journal == null)
            throw new IllegalArgumentException("Dependencies cannot be null");
        this.dispenser = dispenser;
        this.payments = payments;
        this.journal = journal;
    }

    public synchronized void start(String nextOrderId, String nextSlot) {
        if (status == Status.AWAITING_PAYMENT || status == Status.READY || status == Status.DISPENSING)
            throw new IllegalStateException("Order already in progress");
        if (nextOrderId == null || nextOrderId.isEmpty() || nextSlot == null || nextSlot.isEmpty())
            throw new IllegalArgumentException("Order ID and slot are required");
        if (journal.wasAttempted(nextOrderId)) throw new IllegalArgumentException("Order ID already used");
        this.orderId = nextOrderId;
        this.slot = nextSlot;
        status = Status.AWAITING_PAYMENT;
    }

    public synchronized Status vendIfPaid() {
        if (status != Status.AWAITING_PAYMENT) throw new IllegalStateException("Invalid order state");
        if (!payments.isSettled(orderId)) return status;
        status = Status.READY;
        try {
            if (!journal.markAttempted(orderId)) {
                status = Status.FAILED;
                return status;
            }
        } catch (RuntimeException persistenceFailure) {
            // Fail closed: storage failure must not be followed by a motor command.
            status = Status.FAILED;
            return status;
        }
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
