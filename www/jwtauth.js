/*global cordova, module*/

var exec = require("cordova/exec")

var JWTAuth = {
    /*
     * Returns the stored user email.
     * Can return null if the user is not signed in.
     */
    getUserEmail: function () {
        return new Promise(function(resolve, reject) {
             exec(resolve, reject, "JWTAuth", "getUserEmail", []);
        });
    },

    /*
     * Signs the user in and returns the signed in user email.
     */
    signIn: function() {
        return new Promise(function(resolve, reject) {
            exec(resolve, reject, "JWTAuth", "signIn", []);
        });
    },

    getJWT: function(successCallback, errorCallback) {
        exec(successCallback, errorCallback, "JWTAuth", "getJWT", []);
    },
}

module.exports = JWTAuth;
