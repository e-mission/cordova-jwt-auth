package edu.berkeley.eecs.emission.cordova.opcodeauth;

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

public class OPCodePlugin extends CordovaPlugin {
    private static String TAG = "OPCodePlugin";
    private AuthTokenCreator tokenCreator;
    private static final int RESOLVE_ERROR_CODE = 2000;

    @Override
    public boolean execute(String action, JSONArray data, final CallbackContext callbackContext) throws JSONException {
        tokenCreator = AuthTokenCreationFactory.getInstance(cordova.getActivity());
        if (action.equals("getOPCode")) {
            Activity ctxt = cordova.getActivity();
            AuthPendingResult result = tokenCreator.getOPCode();
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
        } else if (action.equals("setOPCode")) {
            String opcode = data.getString(0);
            Log.d(cordova.getActivity(),TAG,
                    "Force setting the prompted auth token = "+opcode);
            try {
                tokenCreator.setOPCode(opcode);
                callbackContext.success(opcode);
                return true;
            } catch (JSONException e) {
                callbackContext.error("JSONException while saving token "+opcode);
                return false;
            }
        } else {
            return false;
        }
    }
}
