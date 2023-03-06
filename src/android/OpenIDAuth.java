package edu.berkeley.eecs.emission.cordova.opcodeauth;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import androidx.annotation.Nullable;

import net.openid.appauth.*;

import com.auth0.android.jwt.*;

import edu.berkeley.eecs.emission.cordova.connectionsettings.ConnectionSettings;
import edu.berkeley.eecs.emission.cordova.unifiedlogger.Log;

import com.google.android.gms.common.api.CommonStatusCodes;
import com.google.android.gms.common.api.Status;

import org.apache.cordova.CordovaPlugin;

/**
 * Created by Andrew-Tan on 8/24/17.
 *
 * Implementation of the generic OpenID auth code to allow developers to login with arbitrary
 * OpenID providers and retrieve user information
 */

class OpenIDAuth implements AuthTokenCreator {
    private CordovaPlugin mPlugin;
    private AuthPendingResult mAuthPending;
    private AuthorizationService mAuthService;
    private OpenIDAuthStateManager mStateManager;
    private Context mCtxt;

    private static final String TAG = "OpenIDAuth";
    private static final int RC_AUTH = 100;

    // This has to be a class instance instead of a singleton like in
    // iOS because we are not supposed to store contexts in static variables
    // singleton pattern has static GoogleAccountManagerAuth -> mCtxt
    OpenIDAuth(Context ctxt) {
        mCtxt = ctxt;
        mAuthService = new AuthorizationService(mCtxt);
        mStateManager = OpenIDAuthStateManager.getInstance(mCtxt);
    }

    @Override
    public AuthPendingResult uiSignIn(CordovaPlugin plugin) {
        this.mAuthPending = new AuthPendingResult();
        this.mPlugin = plugin;

        Uri issuerUri = Uri.parse(ConnectionSettings.getAuthValue(mCtxt, "discoveryURI"));
        AuthorizationServiceConfiguration.fetchFromIssuer(
                issuerUri,
                new AuthorizationServiceConfiguration.RetrieveConfigurationCallback() {
                    public void onFetchConfigurationCompleted(
                            @Nullable AuthorizationServiceConfiguration serviceConfiguration,
                            @Nullable AuthorizationException ex) {
                        if (ex != null) {
                            Log.exception(mCtxt, TAG, ex);
                            return;
                        }

                        // use serviceConfiguration as needed
                        // service configuration retrieved, proceed to authorization...
                        AuthorizationRequest.Builder authRequestBuilder = new AuthorizationRequest.Builder(
                                serviceConfiguration,
                                ConnectionSettings.getAuthValue(mCtxt, "clientID"),
                                ResponseTypeValues.CODE,
                                Uri.parse("emission.auth://oauth2redirect"))
                                .setScope(ConnectionSettings.getAuthValue(mCtxt, "scope"));
                        AuthorizationRequest authRequest = authRequestBuilder.build();

                        // AuthorizationService authService = new AuthorizationService(mCtxt);
                        Intent authIntent = mAuthService.getAuthorizationRequestIntent(authRequest);
                        mPlugin.cordova.setActivityResultCallback(mPlugin);
                        mPlugin.cordova.getActivity().startActivityForResult(authIntent, RC_AUTH);
                    }
                });

        return mAuthPending;
    }

    @Override
    public AuthPendingResult getUserEmail() {
        AuthPendingResult authPending = new AuthPendingResult();
        AuthResult result = new AuthResult(
                new Status(CommonStatusCodes.SUCCESS),
                UserProfile.getInstance(mCtxt).getUserEmail(),
                null);
        authPending.setResult(result);
        return authPending;
    }

    @Override
    public AuthPendingResult getServerToken() {
        final AuthPendingResult authPending = new AuthPendingResult();

        final AuthState currentState = mStateManager.getCurrent();
        currentState.performActionWithFreshTokens(mAuthService,
                new AuthState.AuthStateAction() {
                    @Override
                    public void execute(@Nullable String accessToken,
                                        @Nullable String idToken,
                                        @Nullable AuthorizationException ex) {
                        // Save new auth state to file
                        mStateManager.replace(currentState);

                        if (ex != null) {
                            authPending.setResult(getErrorResult(ex.getLocalizedMessage()));
                            return;
                        }

                        AuthResult result = new AuthResult(
                                new Status(CommonStatusCodes.SUCCESS),
                                getJWTEmail(idToken),
                                idToken);
                        authPending.setResult(result);
                    }
                });

        return authPending;
    }

    @Override
    public void onActivityResult(int requestCode, int resultCode, Intent data) {
        Log.i(mCtxt, TAG, "onActivityResult get called");
        if (requestCode == RC_AUTH) {
            AuthorizationResponse response = AuthorizationResponse.fromIntent(data);
            AuthorizationException ex = AuthorizationException.fromIntent(data);

            // Update AuthState
            if (response != null || ex != null) {
                mStateManager.updateAfterAuthorization(response, ex);
            }

            if (response == null) {
                // authorization failed, check ex for more details
                Log.exception(mCtxt, TAG, ex);
                return;
            }
            // authorization completed
            if (response != null && response.authorizationCode != null) {
                // authorization code exchange is required
                mStateManager.updateAfterAuthorization(response, ex);
                exchangeAuthorizationCode(response);
            } else if (ex != null) {
                Log.exception(mCtxt, TAG, ex);
            } else {
                Log.d(mCtxt, TAG, "No authorization state retained - reauthorization required");
            }
        } else {
            Log.d(mCtxt, TAG, "onActivityResult(" + requestCode + "," + resultCode + "," + data.getDataString());
            Log.i(mCtxt, TAG, "unknown intent, ignoring call...");
        }
    }

    private void exchangeAuthorizationCode(AuthorizationResponse authorizationResponse) {
        performTokenRequest(
                authorizationResponse.createTokenExchangeRequest(),
                new AuthorizationService.TokenResponseCallback() {
                    public void onTokenRequestCompleted(@Nullable TokenResponse tokenResponse,
                                                        @Nullable AuthorizationException authException) {

                        mStateManager.updateAfterTokenResponse(tokenResponse, authException);

                        AuthState authState = mStateManager.getCurrent();
                        if (!authState.isAuthorized()) {
                            final String message = "Authorization Code exchange failed"
                                    + ((authException != null) ? authException.error : "");

                            Log.d(mCtxt, TAG, message);
                        } else {
                            String idToken = authState.getIdToken();
                            Log.i(mCtxt, TAG, "id token retrieved: " + idToken);

                            String userEmail = getJWTEmail(idToken);
                            UserProfile.getInstance(mCtxt).setUserEmail(userEmail);
                            AuthResult authResult = new AuthResult(
                                    new Status(CommonStatusCodes.SUCCESS),
                                    userEmail,
                                    idToken);
                            mAuthPending.setResult(authResult);
                        }
                    }
                });
    }

    private void performTokenRequest(
            TokenRequest request,
            AuthorizationService.TokenResponseCallback callback) {
        ClientAuthentication clientAuthentication;
        try {
            clientAuthentication = mStateManager.getCurrent().getClientAuthentication();
        } catch (ClientAuthentication.UnsupportedAuthenticationMethod ex) {
            Log.d(mCtxt, TAG, "Token request cannot be made, client authentication for the token "
                    + "endpoint could not be constructed");
            return;
        }

        mAuthService.performTokenRequest(
                request,
                clientAuthentication,
                callback);
    }

    private String getJWTEmail(String token) {
        JWT parsedJWT = new JWT(token);
        Claim email = parsedJWT.getClaim("email");
        return email.asString();
    }

    private static AuthResult getErrorResult(String errorMessage) {
        return new AuthResult(new Status(CommonStatusCodes.ERROR, errorMessage), null, null);
    }

    @Override
    public void onNewIntent(Intent intent) {
        Log.d(mCtxt, TAG, "in openid auth code, onIntent(" + intent.getDataString() + " called, ignoring");
    }
}
