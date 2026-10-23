package com.molayo.vendingkiosk;

import org.junit.Test;
import static org.junit.Assert.*;

public class BoardDiagnosticsTest {
    @Test public void simulationDoesNotCaptureOrSend() {
        BoardDiagnostics recorder = new BoardDiagnostics(BoardDiagnostics.Mode.SIMULATION);
        assertFalse(recorder.observe("/dev/ttyS1", BoardDiagnostics.Port.UNKNOWN,
                new byte[]{1, 2}, 1));
        assertFalse(recorder.sendCommand(new byte[]{1, 2}));
        assertTrue(recorder.snapshot().isEmpty());
    }

    @Test public void observeOnlyCapturesInboundHexButNeverCommands() {
        BoardDiagnostics recorder = new BoardDiagnostics(BoardDiagnostics.Mode.OBSERVE_ONLY);
        byte[] bytes = {(byte) 0x80, 0x00, (byte) 0xFF};
        assertTrue(recorder.observe("/dev/ttyS2", BoardDiagnostics.Port.MDB_BRIDGE, bytes, 10));
        bytes[0] = 0;
        assertEquals("8000FF", recorder.snapshot().get(0).payloadHex);
        assertFalse(recorder.sendCommand(new byte[]{0x12}));
    }

    @Test public void malformedOrOversizedFramesRejected() {
        BoardDiagnostics recorder = new BoardDiagnostics(BoardDiagnostics.Mode.OBSERVE_ONLY);
        assertFalse(recorder.observe("", BoardDiagnostics.Port.UNKNOWN, new byte[]{1}, 1));
        assertFalse(recorder.observe("port", BoardDiagnostics.Port.UNKNOWN, new byte[0], 1));
        assertFalse(recorder.observe("port", BoardDiagnostics.Port.UNKNOWN, new byte[4097], 1));
        assertFalse(recorder.observe("port", BoardDiagnostics.Port.UNKNOWN, new byte[]{1}, -1));
        assertTrue(recorder.snapshot().isEmpty());
    }
}
