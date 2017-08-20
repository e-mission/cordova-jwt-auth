package edu.berkeley.eecs.emission.cordova.jwtauth;

import java.io.IOException;

import com.google.android.gms.auth.GoogleAuthException;
import com.google.android.gms.auth.GoogleAuthUtil;
import com.google.android.gms.auth.UserRecoverableAuthException;
import com.google.android.gms.common.AccountPicker;
import com.google.android.gms.common.api.CommonStatusCodes;
import com.google.android.gms.common.api.Status;

import android.accounts.AccountManager;

import edu.berkeley.eecs.emission.cordova.connectionsettings.ConnectionSettings;
import edu.berkeley.eecs.emission.cordova.unifiedlogger.Log;

import android.app.Activity;
import android.app.AlertDialog;
import android.app.PendingIntent;
import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.provider.Settings;

import org.apache.cordova.CordovaPlugin;

class GoogleAccountManagerAuth implements AuthTokenCreator {
	private static final int REQUEST_CODE_PICK_ACCOUNT = 1000;
	private static final int REQUEST_CODE_GET_TOKEN = 1001;
    public static String TAG = "GoogleAccountManagerAuth";

	private CordovaPlugin mPlugin;
	private Context mCtxt;
	private AuthPendingResult mAuthPending;

	// This has to be a class instance instead of a singleton like in
	// iOS because we are not supposed to store contexts in static variables
	// singleton pattern has static GoogleAccountManagerAuth -> mCtxt
	GoogleAccountManagerAuth(Context ctxt) {
		mCtxt = ctxt;
	}

    /*
     * This just invokes the account chooser. The chosen username is returned
     * as a callback to the passed in activity, which then calls onActivityResult here
     * to set the username.
     */
	@Override
	public AuthPendingResult uiSignIn(CordovaPlugin plugin) {
		mPlugin = plugin;
		try {
			String[] accountTypes = new String[]{"com.google"};

			/*
    		Account[] existingAccounts = accountManager.getAccountsByType("com.google");
    		assert(existingAccounts.length >= 1);
        	Toast.makeText(mCtxt, existingAccounts[0].name, Toast.LENGTH_SHORT).show();
    		return existingAccounts[0].name;
			 */
    	
			Intent intent = AccountPicker.newChooseAccountIntent(null, null,
					accountTypes, true, null, null, null, null);

			// Note that because we are starting the activity using mCtxt, the activity callback
			// invoked will not be the one in this class, but the one in the original context.
			// In our current flow, that is the one in the MainActivity
			mAuthPending = new AuthPendingResult();
			// NOTE: I tried setting the result callback to an instance of GoogleAccountManagerAuth,
			// but it has to be a subclass of CordovaPlugin
			// https://github.com/apache/cordova-android/blob/ad01d28351c13390aff4549258a0f06882df59f5/framework/src/org/apache/cordova/CordovaInterface.java#L49
			mPlugin.cordova.setActivityResultCallback(mPlugin);
			// This will not actually return anything - instead we will get a callback in onActivityResult
			mPlugin.cordova.getActivity().startActivityForResult(intent, REQUEST_CODE_PICK_ACCOUNT);
			return mAuthPending;
		} catch (ActivityNotFoundException e) {
			// If the user does not have a google account, then 
			// this exception is thrown
			AlertDialog.Builder alertDialog = new AlertDialog.Builder(mCtxt);
			alertDialog.setTitle("Account missing");
//			alertDialog.setIcon(R.drawable.ic);
			alertDialog.setMessage("Continue by signing in to google");
			alertDialog.setNeutralButton("OK", new DialogInterface.OnClickListener() {
				public void onClick(DialogInterface dialog, int which) {
					mCtxt.startActivity(new Intent(Settings.ACTION_ADD_ACCOUNT));
				}
			});
			alertDialog.show();
		}
		return mAuthPending;
	}

	/*
	 * BEGIN: Calls to get the data
	 * Going to configure these with background (pending) results in order to support background operations
	 * It's really kind of amazing that GoogleAuthUtil doesn't enforce that, and the new
	 * GoogleSignIn code probably will
	 */
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
		AuthPendingResult authPending = new AuthPendingResult();
		try {
			String serverToken = null;
			String AUTH_SCOPE = "audience:server:client_id:"+ConnectionSettings.getGoogleWebAppClientID(mCtxt);
			String userName = UserProfile.getInstance(mCtxt).getUserEmail();
			serverToken = GoogleAuthUtil.getToken(mCtxt,
					userName, AUTH_SCOPE);
			Log.i(mCtxt, TAG, "serverToken = "+serverToken);
			AuthResult result = new AuthResult(
					new Status(CommonStatusCodes.SUCCESS),
					userName,
					serverToken);
			authPending.setResult(result);
		} catch (UserRecoverableAuthException e) {
			PendingIntent intent = PendingIntent.getActivity(mCtxt, REQUEST_CODE_GET_TOKEN,
					e.getIntent(), PendingIntent.FLAG_UPDATE_CURRENT);
			AuthResult result = new AuthResult(
					new Status(CommonStatusCodes.SUCCESS, e.getLocalizedMessage(), intent),
					null,
					null);
			authPending.setResult(result);
			e.printStackTrace();
		} catch (IOException e) {
			authPending.setResult(getErrorResult(e.getLocalizedMessage()));
			e.printStackTrace();
		} catch (GoogleAuthException e) {
			authPending.setResult(getErrorResult(e.getLocalizedMessage()));
			e.printStackTrace();
		}
		return authPending;
	}

	/*
	 * END: Calls to get the data
	 */

	// Similar to handleNotification on iOS
	@Override
	public void onActivityResult(int requestCode, int resultCode, Intent data) {
		if (requestCode == REQUEST_CODE_PICK_ACCOUNT) {
			if (resultCode == Activity.RESULT_OK) {
				String userEmail = data.getStringExtra(AccountManager.KEY_ACCOUNT_NAME);
				UserProfile.getInstance(mCtxt).setUserEmail(userEmail);
				mPlugin.cordova.setActivityResultCallback(null);
				mPlugin = null;
				AuthResult result = new AuthResult(
						new Status(CommonStatusCodes.SUCCESS),
						userEmail,
						null);
				mAuthPending.setResult(result);
			} else {
				mAuthPending.setResult(getErrorResult("Result code = " + resultCode));
			}
		}
	}

	@Override
	public void onNewIntent(Intent intent) {
		Log.d(mCtxt, TAG, "in google auth code, onIntent("+intent.getDataString()+" called, ignoring");
	}

	private static AuthResult getErrorResult(String errorMessage) {
		return new AuthResult(new Status(CommonStatusCodes.ERROR, errorMessage), null, null);
	}
}
