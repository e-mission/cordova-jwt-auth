package edu.berkeley.eecs.emission.cordova.opcodeauth;

import com.google.android.gms.common.api.Result;
import com.google.android.gms.common.api.Status;

/**
 * Result class for async operation.
 * Unsure whether we should use PendingResult for callbacks
 * but it is certainly more consistent with the new google APIs
 */

public class AuthResult implements Result {
    private Status status;
    private String opcode;

    public AuthResult(Status istatus, String iopcode) {
        status = istatus;
        opcode = iopcode;
    }

    @Override
    public Status getStatus() {
        return status;
    }

    public String getOPCode() {
        return opcode;
    }
}
