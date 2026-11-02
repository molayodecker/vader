package com.molayo.vendingkiosk;

import org.junit.Test;
import static org.junit.Assert.*;

public final class SimulatedMachineHardwareTest {
    @Test public void profileDoesNotInventMissingVersions() {
        assertEquals("19265359", ZhongdaMachineProfile.MACHINE_ID);
        assertEquals("3.1.90", ZhongdaMachineProfile.UPPER_SOFTWARE_VERSION);
        assertEquals(100, ZhongdaMachineProfile.REPORTED_SHELF_CAPACITY);
        assertNull(ZhongdaMachineProfile.CONTROL_BOARD_VERSION);
        assertNull(ZhongdaMachineProfile.MDB_VERSION);
    }

    @Test public void simulationHasNoTrustedTemperature() {
        MachineHardware.Status status = new SimulatedMachineHardware().status();
        assertTrue(status.connected);
        assertNull(status.temperatureCelsius);
        assertFalse(status.temperatureVerified);
    }

    @Test public void acknowledgementIsNotDeliveryAndCannotRetry() {
        SimulatedMachineHardware machine = new SimulatedMachineHardware();
        machine.setNextResult(MachineHardware.Result.TIMED_OUT);
        assertFalse(machine.asDispenser().dispense("A1", "order-one"));
        assertEquals(MachineHardware.Result.FAILED, machine.dispense("A1", "order-one"));
        assertTrue(machine.asDispenser().dispense("A1", "order-two"));
    }

    @Test public void offlineAndInvalidRequestsFailClosed() {
        SimulatedMachineHardware machine = new SimulatedMachineHardware();
        machine.setConnected(false);
        assertEquals(MachineHardware.Result.UNAVAILABLE, machine.dispense("A1", "offline"));
        machine.setConnected(true);
        assertEquals(MachineHardware.Result.FAILED, machine.dispense("A1", "offline"));
        assertEquals(MachineHardware.Result.FAILED, machine.dispense("", "other"));
    }

    @Test public void existingVendCoordinatorTreatsTimeoutAsFailure() {
        SimulatedMachineHardware machine = new SimulatedMachineHardware();
        machine.setNextResult(MachineHardware.Result.TIMED_OUT);
        VendController controller = new VendController(machine.asDispenser(), id -> true);
        controller.start("order-timeout", "A1");
        assertEquals(VendController.Status.FAILED, controller.vendIfPaid());
        assertThrows(IllegalStateException.class, controller::vendIfPaid);
    }
}
