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

    getJWT: function() {
        return new Promise(function(resolve, reject) {
            exec(resolve, reject, "JWTAuth", "getJWT", []);
        });
    },

    launchDevAuth: function() {
        var email = window.prompt('Dummy dev mode: Enter email', '');
        // window.alert('email = '+email);
        var callbackURL = 'emission://auth?method=dummy-dev&token='+email;
        // window.alert('callbackURL = '+callbackURL);
        var callbackWindow = cordova.InAppBrowser.open(callbackURL, '_system');
        // Make sure we close the window automatically
        // Note that we can't do this on loadend
        // https://github.com/e-mission/cordova-jwt-auth/issues/17#issuecomment-323645807
        callbackWindow.addEventListener('loadstart', function(event) {
            // Do we even need to check the protocol? This is a callback on *this*
            // IAB instance. And we don't load anything in this IAB
            // instance other than the emission URL
            // Let's leave it in for now since it doesn't hurt anything
            var protocol = event.url.substring(0, event.url.indexOf('://'));
            if (protocol == 'emission') {
                setTimeout(callbackWindow.close(), 5000);
            }
        });

        callbackWindow.addEventListener('loaderr', function(event) {
            alert('Error '+event.message+' loading '+event.url);
            callbackWindow.close();
        });
    }
}

module.exports = JWTAuth;
