package edu.berkeley.eecs.emission.cordova.jwtauth;

import org.apache.cordova.*;
import org.json.JSONArray;
import org.json.JSONException;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import androidx.annotation.NonNull;
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
            AuthPendingResult result = tokenCreator.uiSignIn(this);
            result.setResultCallback(new ResultCallback<AuthResult>() {
                @Override
                public void onResult(@NonNull AuthResult authResult) {
                    if (authResult.getStatus().isSuccess()) {
                        Toast.makeText(cordova.getActivity(), authResult.getEmail(),
                                Toast.LENGTH_SHORT).show();
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
        } else if (action.equals("setPromptedAuthToken")) {
            if (tokenCreator.getClass() != PromptedAuth.class) {
                callbackContext.error("Attempting to set programmatic token conflicts"
                        + "with configured auth method");
            }
            String email = data.getString(0);
            Log.d(cordova.getActivity(),TAG,
                    "Force setting the prompted auth token = "+email);
            UserProfile.getInstance(cordova.getActivity()).setUserEmail(email);
            callbackContext.success(email);
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

    @Override
    public void onNewIntent(Intent intent) {
        Log.d(cordova.getActivity(), TAG, "onNewIntent(" + intent.getDataString() + ")");
        if (tokenCreator != null) {
            tokenCreator.onNewIntent(intent);
        } else {
            Log.i(cordova.getActivity(), TAG, "tokenCreator = null, ignoring intent"+intent.getDataString());
        }
    }
}
