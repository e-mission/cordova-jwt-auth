package edu.berkeley.eecs.emission.cordova.jwtauth;

import org.apache.cordova.*;
import org.json.JSONArray;
import org.json.JSONException;

import android.app.Activity;
import android.content.Intent;
import android.support.annotation.NonNull;
import android.widget.Toast;

import com.google.android.gms.common.api.ResultCallback;

import edu.berkeley.eecs.emission.cordova.unifiedlogger.Log;

public class JWTAuthPlugin extends CordovaPlugin {
    private static String TAG = "JWTAuthPlugin";
    private AuthTokenCreator tokenCreator;
    private static final int RESOLVE_ERROR_CODE = 2000;

    @Override
    public boolean execute(String action, JSONArray data, final CallbackContext callbackContext) throws JSONException {
        tokenCreator = AuthTokenCreationFactory.getInstance(cordova.getActivity());
        if (action.equals("getUserEmail")) {
            Activity ctxt = cordova.getActivity();
            AuthPendingResult result = tokenCreator.getUserEmail();
            result.setResultCallback(new ResultCallback<AuthResult>() {
                @Override
                public void onResult(@NonNull AuthResult authResult) {
                    if (authResult.getStatus().isSuccess()) {
                        callbackContext.success(authResult.getEmail());
                    } else {
                        callbackContext.error(authResult.getStatus().getStatusCode() + " : "+
                                authResult.getStatus().getStatusMessage());
                    }
                }
            });
            return true;
        } else if (action.equals("signIn")) {
            // NOTE: I tried setting the result callback to an instance of GoogleAccountManagerAuth,
            // but it has to be a subclass of CordovaPlugin
            // https://github.com/apache/cordova-android/blob/ad01d28351c13390aff4549258a0f06882df59f5/framework/src/org/apache/cordova/CordovaInterface.java#L49
            cordova.setActivityResultCallback(this);
            // This will not actually return anything - instead we will get a callback in onActivityResult
            AuthPendingResult result = tokenCreator.uiSignIn();
            result.setResultCallback(new ResultCallback<AuthResult>() {
                @Override
                public void onResult(@NonNull AuthResult authResult) {
                    if (authResult.getStatus().isSuccess()) {
                        Toast.makeText(cordova.getActivity(), authResult.getEmail(),
                                Toast.LENGTH_SHORT).show();
                        cordova.setActivityResultCallback(null);
                        callbackContext.success(authResult.getEmail());
                    } else {
                        callbackContext.error(authResult.getStatus().getStatusCode() + " : "+
                                authResult.getStatus().getStatusMessage());
                    }
                }
            });
            return true;
        } else if (action.equals("getJWT")) {
            AuthPendingResult result = tokenCreator.getServerToken();
            result.setResultCallback(new ResultCallback<AuthResult>() {
                @Override
                public void onResult(@NonNull AuthResult authResult) {
                    if (authResult.getStatus().isSuccess()) {
                        callbackContext.success(authResult.getToken());
                    } else {
                        callbackContext.error(authResult.getStatus().getStatusCode() + " : "+
                                authResult.getStatus().getStatusMessage());
                    }
                    // TODO: Figure out how to handle pending status codes here
                    // Would be helpful if I could actually generate some to test :)
                }
            });
            return true;
        } else {
            return false;
        }
    }

    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        Log.d(cordova.getActivity(), TAG, "requestCode = " + requestCode + " resultCode = " + resultCode);
        tokenCreator.onActivityResult(requestCode, resultCode, data);
    }
}
