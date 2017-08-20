package edu.berkeley.eecs.emission.cordova.jwtauth;

import android.content.Context;

import edu.berkeley.eecs.emission.cordova.connectionsettings.ConnectionSettings;

/**
 * Created by shankari on 8/19/17.
 *
 * Factory to generate AuthTokenCreator instances based on the connection settings
 */

public class AuthTokenCreationFactory {
    public static AuthTokenCreator getInstance(Context ctxt) {
        String authMethod = ConnectionSettings.getAuthMethod(ctxt);
        if ("google-authutil".equals(authMethod)) {
            return new GoogleAccountManagerAuth(ctxt);
        } else {
            throw new RuntimeException("No auth creator found for method "+authMethod);
        }
    }
}
