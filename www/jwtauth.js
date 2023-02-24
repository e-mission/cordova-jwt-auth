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
     * Although we generally support auth through callbacks, this is special
     * because we may want to call it from the client to programatically create
     * a string or token and we don't want to jump through in app browser hoops
     * to do so.
     */

    setPromptedAuthToken(email) {
        return new Promise(function(resolve, reject) {
            exec(resolve, reject, "JWTAuth", "setPromptedAuthToken", [email]);
        });
    },
}

module.exports = JWTAuth;
