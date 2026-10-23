package com.molayo.vendingkiosk;

import android.content.Context;
import android.content.SharedPreferences;

/** Prototype-local write-ahead attempt flag; does not replace a backend order ledger. */
public final class PreferencesAttemptJournal implements VendController.AttemptJournal {
    private final SharedPreferences prefs;

    public PreferencesAttemptJournal(Context context) {
        prefs = context.getApplicationContext().getSharedPreferences("vend_attempts_v1", Context.MODE_PRIVATE);
    }

    @Override public synchronized boolean wasAttempted(String orderId) {
        return prefs.getBoolean("attempt:" + orderId, false);
    }

    @Override public synchronized boolean markAttempted(String orderId) {
        if (wasAttempted(orderId)) return false;
        // commit() is synchronous; apply() would allow the motor command to race persistence.
        if (!prefs.edit().putBoolean("attempt:" + orderId, true).commit())
            throw new IllegalStateException("Could not durably record dispense attempt");
        return true;
    }
}
