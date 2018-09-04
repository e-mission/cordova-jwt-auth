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
        } else if ("openid-authutil".equals(authMethod)) {
            return new OpenIDAuth(ctxt);
        } else if ("prompted-auth".equals(authMethod)) {
            return new PromptedAuth(ctxt);
        } else {
            // Return dummy dev sign-in handler by default so that:
            // - we know that this will never return null
            // - dev users can start working without any configuration stuff
            return new PromptedAuth(ctxt);
        }
    }
}
