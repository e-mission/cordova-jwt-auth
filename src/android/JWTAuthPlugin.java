package edu.berkeley.eecs.emission.cordova.jwtauth;

import org.apache.cordova.*;
import org.json.JSONArray;
import org.json.JSONException;

import android.accounts.AccountManager;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.widget.Toast;

import edu.berkeley.eecs.emission.cordova.unifiedlogger.Log;

public class JWTAuthPlugin extends CordovaPlugin {
    private static String TAG = "JWTAuthPlugin";
    private static final int REQUEST_CODE_PICK_ACCOUNT = 1000;
    private CallbackContext savedContext;

    @Override
    public boolean execute(String action, JSONArray data, CallbackContext callbackContext) throws JSONException {
        if (action.equals("getUserEmail")) {
            Context ctxt = cordova.getActivity();
            String userEmail = UserProfile.getInstance(ctxt).getUserEmail();
            callbackContext.success(userEmail);
            return true;
        } else if (action.equals("signIn")) {
            cordova.setActivityResultCallback(this);
            savedContext = callbackContext;
            // This will not actually return anything - instead we will get a callback in onActivityResult
            new GoogleAccountManagerAuth(cordova.getActivity(), REQUEST_CODE_PICK_ACCOUNT).getUserName();
            return true;
        } else if (action.equals("getJWT")) {
            Context ctxt = cordova.getActivity();
            String token = GoogleAccountManagerAuth.getServerToken(ctxt, edu.berkeley.eecs.emission.cordova.jwtauth.UserProfile.getInstance(ctxt).getUserEmail());
            callbackContext.success(token);
            return true;
        } else {
            return false;
        }
    }

    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        Log.d(cordova.getActivity(), TAG, "requestCode = " + requestCode + " resultCode = " + resultCode);
        if (requestCode == REQUEST_CODE_PICK_ACCOUNT) {
            if (resultCode == Activity.RESULT_OK) {
                String userEmail = data.getStringExtra(AccountManager.KEY_ACCOUNT_NAME);
                Context ctxt = cordova.getActivity();
                Toast.makeText(ctxt, userEmail, Toast.LENGTH_SHORT).show();
                UserProfile.getInstance(ctxt).setUserEmail(userEmail);
                UserProfile.getInstance(ctxt).setGoogleAuthDone(true);
                cordova.setActivityResultCallback(null);
                savedContext.success(userEmail);
            } else {
                savedContext.error("Request code = "+resultCode);
            }
        }
    }
}
