package edu.berkeley.eecs.emission.cordova.jwtauth;

import org.apache.cordova.*;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.content.Intent;

import edu.berkeley.eecs.cfc_tracker.ConnectionSettings;

private static String TAG = "JWTAuthPlugin";

public class JWTAuthPlugin extends CordovaPlugin {
    private CallbackContext savedContext;

    @Override
    public boolean execute(String action, JSONArray data, CallbackContext callbackContext) throws JSONException {
        if (action.equals("getUserEmail")) {
            Context ctxt = cordova.getActivity();
            String userEmail = UserProfile.getInstance(ctxt).getUserEmail();
            callbackContext.success(userEmail);
            return true;
        } else if (action.equals("signIn")) {
            cordova.getInterface().setActivityResultCallback(this);
            savedContext = callbackContext;
            GoogleAuthManagerActivity(cordova.getActivity(), REQUEST_CODE_PICK_ACCOUNT);
            return true;
        } else if (action.equals("getJWT")) {
            Context ctxt = cordova.getActivity();
            String token = GoogleAccountManagerAuth.getServerToken(ctxt, UserProfile.getInstance(ctxt).getUserEmail());
            callbackContext.success(token);
            return true;
        } else {
            return false;
        }
    }

    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        Log.d(cordova.getActivity(), "TAG, requestCode = "+requestCode+" resultCode = "+resultCode);
        if (requestCode == REQUEST_CODE_PICK_ACCOUNT) {
            if (resultCode == Activity.RESULT_OK) {
                String userEmail = data.getStringExtra(AccountManager.KEY_ACCOUNT_NAME);
                Context ctxt = cordova.getActivity();
                Toast.makeText(ctxt, userEmail, Toast.LENGTH_SHORT).show();
                UserProfile.getInstance(ctxt).setUserEmail(userEmail);
                UserProfile.getInstance(ctxt).setGoogleAuthDone(true);
                cordova.getInterface().setActivityResultCallback(null);
                savedContext.success(userEmail);
            } else {
                savedContext.error("Request code = "+resultCode);
            }
        }
    }
}
