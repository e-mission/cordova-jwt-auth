package edu.berkeley.eecs.emission.cordova.opcodeauth;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import androidx.annotation.NonNull;

import edu.berkeley.eecs.emission.cordova.connectionsettings.ConnectionSettings;
import edu.berkeley.eecs.emission.cordova.unifiedlogger.Log;
import edu.berkeley.eecs.emission.cordova.usercache.UserCacheFactory;

import com.google.android.gms.common.api.CommonStatusCodes;
import com.google.android.gms.common.api.Status;

import org.apache.cordova.CordovaPlugin;
import org.json.JSONException;
import org.json.JSONObject;

/**
 * Created by shankari on 8/21/17.
 *
 * Implementation of the prompted auth code to allow developers to login with multiple user IDs
 * for testing + to provide another exemplar of logging in properly :)
 */

class PromptedAuth implements AuthTokenCreator {
    private CordovaPlugin mPlugin;
    private AuthPendingResult mAuthPending;
    private Context mCtxt;

    private static final String TAG = "PromptedAuth";
    private static final String METHOD_PARAM_KEY = "method";
    private static final String TOKEN_PARAM_KEY = "token";
    private static final String EXPECTED_HOST = "auth";
    private static final String EXPECTED_METHOD = "prompted-auth";

    // This has to be a class instance instead of a singleton like in
    // iOS because we are not supposed to store contexts in static variables
    // singleton pattern has static GoogleAccountManagerAuth -> mCtxt
    PromptedAuth(Context ctxt) {
        mCtxt = ctxt;
    }

    @Override
    public AuthPendingResult getOPCode() {
        return readStoredUserAuthEntry(mCtxt);
    }

    @Override
    public AuthPendingResult getServerToken() {
        // For the prompted-auth case, the token is the user email
        return readStoredUserAuthEntry(mCtxt);
    }

    private AuthPendingResult readStoredUserAuthEntry(Context ctxt) {
        AuthPendingResult authPending = new AuthPendingResult();
        AuthResult result = null;
        try {
            String token = null;
            JSONObject dbStorageObject = UserCacheFactory.getUserCache(ctxt).getLocalStorage(EXPECTED_METHOD, false);
            if (dbStorageObject == null) {
                Log.i(ctxt, TAG, "Auth not found in local storage, copying from user profile");
                String profileToken = UserProfile.getInstance(ctxt).getUserEmail();
                Log.i(ctxt, TAG, "Profile token = " + profileToken);
                dbStorageObject = new JSONObject();
                dbStorageObject.put(TOKEN_PARAM_KEY, profileToken);
                UserCacheFactory.getUserCache(ctxt).putLocalStorage(EXPECTED_METHOD, dbStorageObject);
                token = profileToken;
            } else {
                token = dbStorageObject.getString(TOKEN_PARAM_KEY);
                Log.i(ctxt, TAG,"Auth found in local storage, now it should be stable");
            }
            result = new AuthResult(
                new Status(CommonStatusCodes.SUCCESS),
                    token, token);
        } catch (JSONException e) {
            result = new AuthResult(
                    new Status(CommonStatusCodes.ERROR),
                    e.getLocalizedMessage(), e.getLocalizedMessage());
        }
        authPending.setResult(result);
        return authPending;
    }

    @Override
    public void setOPCode(String opcode) throws JSONException {
        // For the prompted-auth case, the token is the user email
        writeStoredUserAuthEntry(mCtxt, opcode);
    }

    private void writeStoredUserAuthEntry(Context ctxt, String opcode) throws JSONException {
        JSONObject dbStorageObject = new JSONObject();
        dbStorageObject.put(TOKEN_PARAM_KEY, opcode);
        UserCacheFactory.getUserCache(ctxt).putLocalStorage(EXPECTED_METHOD, dbStorageObject);
    }
}
