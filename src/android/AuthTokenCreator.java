package edu.berkeley.eecs.emission.cordova.opcodeauth;

import android.content.Intent;
import android.content.Context;
import org.json.JSONException;

/**
 * Created by shankari on 8/19/17.
 *
 * Interface that defines the methods that all auth handlers must define.
 */

public interface AuthTokenCreator {
    public AuthPendingResult getOPCode();
    public AuthPendingResult getServerToken();
    public void setOPCode(String token) throws JSONException;
}
