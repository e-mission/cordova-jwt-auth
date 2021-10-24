Cordova JWT Auth OpenID support
---

🚧 This functionality is currently untested in the most recent version (1.6.5) since I don't have a server to test against.
If you use OpenID Auth and find errors, please contact me with information about your server so I can fix it 🚧 

🗑️ If this functionality is not currently used, I might deprecate it in the
next release and remove in 2 releases later. So if you do use this
functionality, please speak up! 🗑️

The plugin currently supports login with generic OpenID providers, while a few additional configuration needed to be 
made in order for the plugin to function.


Important Notes
---
Note that currently this is a Android-Only feature, iOS will be supported soon.

Usage
---
To start using OpenID login, edit connection setting `www/json/connectionConfig.json`.

A few key/value pairs are required:
1. `method`: set the value of this key to be `openid-authutil`.

2. `discoveryURI`: this is where the OpenID configuration stored. More info about discovery/web finger can be found in
[the spec of OpenID](https://openid.net/specs/openid-connect-discovery-1_0.html). Note that if your discovery config is
at, for example, `https://example.com/.well-known/openid-configuration`, only put in `https://example.com/`. Manual
configuration will be supported in the future.

3. `clientID`: the client ID of the registered client. While client credential is also planning to be supported in the
future, dynamic client registration is not yet planned to be supported.

4. `scope`: scope to be requested. `openid email profile offline_access` should be sufficient at this point. Note that
`offline_access` should always be added in order to avoid token error when app is in background.

Example
---
```
{
  ...
  "android": {
    "auth": {
      "method": "openid-authutil",
      "discoveryURI": "https://example.com/",
      "clientID": "example-client-id",
      "scope": "openid email profile offline_access"
    }
  },
  ...
}
```

Developer's Note
---
1. For Android, `android support` conflict found in development. The current workaround is to force all android support
version to be the same. If some library needs higher android support version in the future, please bump up the version
in `src/android/openid-config.gradle`
