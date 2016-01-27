/*global cordova, module*/

var exec = require("cordova/exec")

var JWTAuth = {
    /*
     * Returns the stored user email.
     * Can return null if the user is not signed in.
     */
    getUserEmail: function (successCallback, errorCallback) {
        exec(successCallback, errorCallback, "JWTAuth", "getSignedInEmail", [level, message]);
    },

    /*
     * Signs the user in and returns the signed in user email.
     */
    signIn: function(successCallback, errorCallback) {
        exec(successCallback, errorCallback, "JWTAuth", "signIn", []);
    },

    getJWT: function(successCallback, errorCallback) {
        exec(successCallback, errorCallback, "JWTAuth", "getJWT", []);
    },
}

module.exports = JWTAuth;
