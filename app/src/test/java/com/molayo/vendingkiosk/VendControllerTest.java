package com.molayo.vendingkiosk;

import org.junit.Test;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.HashSet;
import java.util.Set;
import static org.junit.Assert.*;

public final class VendControllerTest {
    @Test public void unpaidOrderDoesNotDispense() {
        AtomicInteger attempts = new AtomicInteger();
        VendController controller = new VendController((slot, id) -> { attempts.incrementAndGet(); return true; }, id -> false);
        controller.start("order-1", "A1");
        assertEquals(VendController.Status.AWAITING_PAYMENT, controller.vendIfPaid());
        assertEquals(0, attempts.get());
    }

    @Test public void paidOrderDispensesExactlyOnce() {
        AtomicInteger attempts = new AtomicInteger();
        VendController controller = new VendController((slot, id) -> { attempts.incrementAndGet(); return true; }, id -> true);
        controller.start("order-2", "B2");
        assertEquals(VendController.Status.COMPLETE, controller.vendIfPaid());
        assertEquals(1, attempts.get());
        assertThrows(IllegalStateException.class, controller::vendIfPaid);
        assertThrows(IllegalArgumentException.class, () -> controller.start("order-2", "B2"));
        assertEquals(1, attempts.get());
    }

    @Test public void failureIsNotBlindlyRetried() {
        AtomicInteger attempts = new AtomicInteger();
        VendController controller = new VendController((slot, id) -> { attempts.incrementAndGet(); return false; }, id -> true);
        controller.start("order-3", "C1");
        assertEquals(VendController.Status.FAILED, controller.vendIfPaid());
        assertThrows(IllegalStateException.class, controller::vendIfPaid);
        assertThrows(IllegalArgumentException.class, () -> controller.start("order-3", "C1"));
        assertEquals(1, attempts.get());
    }

    @Test public void exceptionFromHardwareMarksOrderFailed() {
        VendController controller = new VendController((slot, id) -> { throw new IllegalStateException("serial timeout"); }, id -> true);
        controller.start("order-4", "A2");
        assertEquals(VendController.Status.FAILED, controller.vendIfPaid());
    }

    @Test public void secondOrderCannotInterruptActiveOrder() {
        VendController controller = new VendController((slot, id) -> true, id -> false);
        controller.start("order-5", "A1");
        assertThrows(IllegalStateException.class, () -> controller.start("order-6", "A2"));
    }

    @Test public void paidOrderCanBeFollowedByNewOrder() {
        AtomicInteger attempts = new AtomicInteger();
        VendController controller = new VendController((slot, id) -> { attempts.incrementAndGet(); return true; }, id -> true);
        controller.start("order-7", "A1");
        assertEquals(VendController.Status.COMPLETE, controller.vendIfPaid());
        controller.start("order-8", "A2");
        assertEquals(VendController.Status.COMPLETE, controller.vendIfPaid());
        assertEquals(2, attempts.get());
    }

    @Test public void missingIdentifiersAreRejected() {
        VendController controller = new VendController((slot, id) -> true, id -> true);
        assertThrows(IllegalArgumentException.class, () -> controller.start("", "A1"));
        assertThrows(IllegalArgumentException.class, () -> controller.start("order-9", null));
    }

    @Test public void restartCannotRepeatPreviouslyAttemptedVend() {
        Set<String> durableIds = new HashSet<>();
        VendController.AttemptJournal sharedJournal = new VendController.AttemptJournal() {
            @Override public boolean wasAttempted(String id) { return durableIds.contains(id); }
            @Override public boolean markAttempted(String id) { return durableIds.add(id); }
        };
        AtomicInteger physicalWrites = new AtomicInteger();
        VendController first = new VendController((slot,id) -> { physicalWrites.incrementAndGet(); return false; }, id -> true, sharedJournal);
        first.start("stable-order-id", "A1");
        assertEquals(VendController.Status.FAILED, first.vendIfPaid());

        VendController afterRestart = new VendController((slot,id) -> { physicalWrites.incrementAndGet(); return true; }, id -> true, sharedJournal);
        assertThrows(IllegalArgumentException.class, () -> afterRestart.start("stable-order-id", "A1"));
        assertEquals(1, physicalWrites.get());
    }

    @Test public void failedJournalWriteBlocksDispensing() {
        AtomicInteger physicalWrites = new AtomicInteger();
        VendController.AttemptJournal storageFailure = new VendController.AttemptJournal() {
            @Override public boolean wasAttempted(String id) { return false; }
            @Override public boolean markAttempted(String id) { throw new IllegalStateException("disk full"); }
        };
        VendController controller = new VendController((slot,id) -> { physicalWrites.incrementAndGet(); return true; }, id -> true, storageFailure);
        controller.start("order-disk-error", "C2");
        assertEquals(VendController.Status.FAILED, controller.vendIfPaid());
        assertEquals(0, physicalWrites.get());
    }

    @Test public void duplicateJournalRecordBlocksDispensing() {
        AtomicInteger physicalWrites = new AtomicInteger();
        VendController.AttemptJournal duplicate = new VendController.AttemptJournal() {
            @Override public boolean wasAttempted(String id) { return false; }
            @Override public boolean markAttempted(String id) { return false; }
        };
        VendController controller = new VendController((slot,id) -> { physicalWrites.incrementAndGet(); return true; }, id -> true, duplicate);
        controller.start("order-concurrent", "B2");
        assertEquals(VendController.Status.FAILED, controller.vendIfPaid());
        assertEquals(0, physicalWrites.get());
    }
}
