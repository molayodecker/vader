package com.molayo.vendingkiosk;

/** Observations from Zhongda Cloud, not a verified hardware specification. */
public final class ZhongdaMachineProfile {
    public static final String MACHINE_ID = "19265359";
    public static final String DEVICE_NAME = "M19265359";
    public static final String UPPER_SOFTWARE_VERSION = "3.1.90";
    public static final String UPPER_PLATFORM = "Android";
    public static final String MOTOR_DESCRIPTION = "3-wire single-feedback";
    public static final int REPORTED_SHELF_CAPACITY = 100;

    // Blank in the cloud details; do not infer MDB compatibility or firmware.
    public static final String CONTROL_BOARD_VERSION = null;
    public static final String MDB_VERSION = null;

    private ZhongdaMachineProfile() { }
}
