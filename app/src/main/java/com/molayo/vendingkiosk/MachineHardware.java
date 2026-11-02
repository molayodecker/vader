package com.molayo.vendingkiosk;

/** Hardware-independent kiosk boundary. Implementations must not guess vendor commands. */
public interface MachineHardware {
    enum Result { DELIVERED, FAILED, TIMED_OUT, UNAVAILABLE }

    final class Status {
        public final boolean connected;
        public final Double temperatureCelsius;
        public final boolean temperatureVerified;

        public Status(boolean connected, Double temperatureCelsius, boolean temperatureVerified) {
            this.connected = connected;
            this.temperatureCelsius = temperatureCelsius;
            this.temperatureVerified = temperatureVerified;
        }
    }

    Status status();

    /** DELIVERED requires actual delivery feedback, never just a serial ACK. */
    Result dispense(String slot, String orderId);
}
