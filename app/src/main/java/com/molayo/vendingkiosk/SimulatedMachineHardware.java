package com.molayo.vendingkiosk;

import java.util.HashSet;
import java.util.Set;

/** Deterministic demo adapter: no ports, payment networks, or motor commands. */
public final class SimulatedMachineHardware implements MachineHardware {
    private final Set<String> seenOrders = new HashSet<>();
    private Result nextResult = Result.DELIVERED;
    private boolean connected = true;

    public synchronized void setNextResult(Result result) {
        if (result == null) throw new IllegalArgumentException("Result required");
        nextResult = result;
    }

    public synchronized void setConnected(boolean connected) { this.connected = connected; }

    @Override public synchronized Status status() {
        // Vendor-reported -39 C is unverified and must not be used for safety decisions.
        return new Status(connected, null, false);
    }

    @Override public synchronized Result dispense(String slot, String orderId) {
        if (slot == null || slot.trim().isEmpty() || orderId == null || orderId.trim().isEmpty())
            return Result.FAILED;
        if (!seenOrders.add(orderId)) return Result.FAILED;
        if (!connected) return Result.UNAVAILABLE;
        Result result = nextResult;
        nextResult = Result.DELIVERED;
        return result;
    }

    /** Adapter for the existing boolean VendController contract; fail closed on uncertainty. */
    public VendController.Dispenser asDispenser() {
        return (slot, orderId) -> dispense(slot, orderId) == Result.DELIVERED;
    }
}
