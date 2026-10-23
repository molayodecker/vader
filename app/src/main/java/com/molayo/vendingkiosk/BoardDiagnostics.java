package com.molayo.vendingkiosk;

import java.util.ArrayList;
import java.util.Collections;
import java.util.List;

/**
 * Read-only protocol-discovery boundary. This class never opens a device,
 * writes a serial frame, parses an unknown message as a vend command, or
 * represents captured traffic as proof of food-safe machine operation.
 *
 * Later a board-specific implementation may feed inbound bytes to this
 * recorder. LIVE motor control requires a separate reviewed implementation.
 */
public final class BoardDiagnostics {
    public enum Mode { SIMULATION, OBSERVE_ONLY }
    public enum Port { UNKNOWN, MOTOR_BOARD, MDB_BRIDGE, REFRIGERATION }

    public static final class Capture {
        public final String portLabel;
        public final Port candidate;
        public final String payloadHex;
        public final long monotonicMillis;

        private Capture(String label, Port candidate, String payloadHex, long time) {
            this.portLabel = label;
            this.candidate = candidate;
            this.payloadHex = payloadHex;
            this.monotonicMillis = time;
        }
    }

    private final Mode mode;
    private final List<Capture> captures = new ArrayList<>();
    private static final int MAX_CAPTURES = 1000;
    private static final int MAX_FRAME_BYTES = 4096;

    public BoardDiagnostics(Mode mode) {
        if (mode == null) throw new IllegalArgumentException("Mode required");
        this.mode = mode;
    }

    public Mode mode() { return mode; }

    /** Record an inbound frame only; callers must not include secrets or customer data. */
    public synchronized boolean observe(String portLabel, Port candidate, byte[] inbound,
                                         long monotonicMillis) {
        if (mode != Mode.OBSERVE_ONLY || portLabel == null || portLabel.isEmpty()
                || portLabel.length() > 128 || candidate == null || inbound == null
                || inbound.length == 0 || inbound.length > MAX_FRAME_BYTES
                || monotonicMillis < 0) return false;
        char[] hex = "0123456789ABCDEF".toCharArray();
        char[] encoded = new char[inbound.length * 2];
        for (int i = 0; i < inbound.length; i++) {
            encoded[i * 2] = hex[(inbound[i] & 0xff) >>> 4];
            encoded[i * 2 + 1] = hex[inbound[i] & 15];
        }
        if (captures.size() == MAX_CAPTURES) captures.remove(0);
        captures.add(new Capture(portLabel, candidate, new String(encoded), monotonicMillis));
        return true;
    }

    public synchronized List<Capture> snapshot() {
        return Collections.unmodifiableList(new ArrayList<>(captures));
    }

    /** Explicit fail-closed placeholder: no guessed byte commands may be sent. */
    public boolean sendCommand(byte[] ignored) {
        return false;
    }
}
