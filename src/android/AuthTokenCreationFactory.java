package edu.berkeley.eecs.emission.cordova.opcodeauth;

import android.content.Context;

import edu.berkeley.eecs.emission.cordova.connectionsettings.ConnectionSettings;

/**
 * Created by shankari on 8/19/17.
 *
 * Factory to generate AuthTokenCreator instances based on the connection settings
 */

public class AuthTokenCreationFactory {
    public static AuthTokenCreator getInstance(Context ctxt) {
        return new PromptedAuth(ctxt);
    }
}
