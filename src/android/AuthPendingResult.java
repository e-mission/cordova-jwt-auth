package edu.berkeley.eecs.emission.cordova.opcodeauth;

import android.os.AsyncTask;
import androidx.annotation.NonNull;

import com.google.android.gms.common.api.CommonStatusCodes;
import com.google.android.gms.common.api.PendingResult;
import com.google.android.gms.common.api.ResultCallback;
import com.google.android.gms.common.api.Status;

import java.util.concurrent.TimeUnit;

import edu.berkeley.eecs.emission.BuildConfig;
import android.util.Log;

public class AuthPendingResult extends PendingResult<AuthResult> {
    private static final String TAG = "AuthPendingResult";
    private final Object syncToken = new Object();

    private AuthResult mAuthResult;
    private boolean mCancelled;
    private ResultCallback<? super AuthResult> mResultCallback;

    protected AuthPendingResult() {
        mAuthResult = null;
        mResultCallback = null;
        mCancelled = false;
    }

    @NonNull
    @Override
    public AuthResult await() {
        synchronized (syncToken) {
            if (mAuthResult != null) {
                return mAuthResult;
            } // else
            try {
                syncToken.wait();
                if (BuildConfig.DEBUG) {
                    if (mAuthResult == null) {
                        throw new RuntimeException("in await, notify received,"
                                + " but mAuthResult = null");
                    }
                }
            } catch (InterruptedException e) {
                mAuthResult = new AuthResult(new Status(CommonStatusCodes.INTERRUPTED), null, null);
            }
            return mAuthResult;
        }
    }

    @NonNull
    @Override
    public AuthResult await(long l, @NonNull TimeUnit timeUnit) {
        synchronized (syncToken) {
            if (mAuthResult != null) {
                return mAuthResult;
            }
            try {
                syncToken.wait(timeUnit.toMillis(l));
                if (BuildConfig.DEBUG) {
                    if (mAuthResult == null) {
                        throw new RuntimeException("in await, notify received,"
                                + " but mAuthResult = null");
                    }
                }
            } catch (InterruptedException e) {
                mAuthResult = new AuthResult(new Status(CommonStatusCodes.INTERRUPTED), null, null);
            }
        }
        return mAuthResult;
    }

    @Override
    public void cancel() {
        synchronized(syncToken) {
            mAuthResult = new AuthResult(new Status(CommonStatusCodes.CANCELED), null, null);
            mCancelled = true;
            syncToken.notify();
            if (mResultCallback != null) {
                mResultCallback.onResult(mAuthResult);
            }
        }
    }

    @Override
    public boolean isCanceled() {
        return mCancelled;
    }

    @Override
    public void setResultCallback(@NonNull ResultCallback<? super AuthResult> resultCallback) {
        synchronized (syncToken) {
            mResultCallback = resultCallback;
            if (mAuthResult != null) {
                mResultCallback.onResult(mAuthResult);
            }
        }
    }

    @Override
    public void setResultCallback(@NonNull ResultCallback<? super AuthResult> resultCallback, long l, @NonNull TimeUnit timeUnit) {
        synchronized (syncToken) {
            mResultCallback = resultCallback;
            if (mAuthResult != null) {
                mResultCallback.onResult(mAuthResult);
            }
        }
        if (mAuthResult == null) {
            AsyncTask<Long, Integer, Void> sleepTask = new AsyncTask<Long, Integer, Void>() {
                @Override
                protected Void doInBackground(Long... millis) {
                    try {
                        long millisecs = millis[0];
                        Thread.sleep(millisecs);
                        synchronized (syncToken) {
                            if (mAuthResult == null) {
                                AuthResult timeoutResult = new AuthResult(
                                        new com.google.android.gms.common.api.Status(CommonStatusCodes.TIMEOUT), null, null);
                                mResultCallback.onResult(timeoutResult);
                                mResultCallback = null;
                            } else {
                                Log.d(TAG, "Result already set, nothing to do");
                            }
                        }
                    } catch (InterruptedException e) {
                        synchronized (syncToken) {
                            AuthResult timeoutResult = new AuthResult(
                                    new com.google.android.gms.common.api.Status(CommonStatusCodes.INTERRUPTED), null, null);
                            mResultCallback.onResult(timeoutResult);
                            mResultCallback = null;
                        }
                    }
                    return null;
                }
            };
            sleepTask.execute(timeUnit.toMillis(l));
        } else {
            Log.d(TAG, "Result already set, nothing to do");
        }
    }

    protected void setResult(AuthResult result) {
        synchronized (syncToken) {
            mAuthResult = result;
            syncToken.notifyAll();
            if (mResultCallback != null) {
                mResultCallback.onResult(mAuthResult);
            }
        }
    }
}
