/*global cordova, module*/

var exec = require("cordova/exec")

var OPCodeAuth = {
    /*
     * Returns the stored OPCode (aka token)
     * Can return null if the user is not signed in.
     */
    getOPCode: function () {
        return new Promise(function(resolve, reject) {
             exec(resolve, reject, "OPCodeAuth", "getOPCode", []);
        });
    },

    /*
     * Corresponding "set" method since we generate the OPCode (aka token) in
     * the phone app and just pass it here for storage.
     */

    setOPCode(opcode) {
        return new Promise(function(resolve, reject) {
            exec(resolve, reject, "OPCodeAuth", "setOPCode", [opcode]);
        });
    },
}

module.exports = OPCodeAuth;
