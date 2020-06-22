This file lists the library dependencies for this plugin and their licenses.

1. These libraries are downloaded automatically and linked to the final binary.
I am not sure how android or iOS link their binaries. However, the xcode link
command uses `-llibname` extensively, so I assume static linkage in general.

1. So our primary check here is for libraries which do not have a license, or
which are GPL licensed.

# Native libraries installed via maven/cocoapods

| Module | License |
|--------|---------|
| com.google.android.gms:play-services-auth | Proprietary (Google) |
| com.auth0.android:jwtdecode | MIT |
| net.openid:appauth | Apache 2.0 |
| SystemConfiguration framework | Proprietary (Apple) |
| Security framework | Proprietary (Apple) |
| GoogleSignIn pod | Proprietary |
| AppAuth pod | Apache 2.0 |
| JWT pod | MIT |
