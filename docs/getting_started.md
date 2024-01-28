# Getting Started

## About Credentials and Tokens

Twitch uses OAuth tokens for EventSub and its REST API.
Tmi.gd is capable of requesting and autorefreshing tokens on your behalf when provided a client id and secret.

If you do not use Twitch OAuth Tokens, you will only have access to messages from IRC.  Messages will also be missing Twitch API provided extended profile information, such as Profile Images.

The advantage of using unauthenticated IRC sessions is the ability to listen to chat messages from any channel on twitch.

EventSub sessions typically are linked strictly to the user and channel that you authenticated with, or a channel that the authenticated user moderates.  If you are not a moderator in the target channel, you can still listen to events but will not receive the majority of the different types.

## Creating credentials

### Local OAuth

Fetching the initial OAuth token using clientId and clientSecret requires manual user validation.  This is normally provided through the twitch CLI when requesting a new token and authorizing with the browser popup.

Also provided is a convenient OAuth service, which provides a request for a token with all required scopes for you, and callback to http://localhost:3000.  This allows you to use a simple web interface and twitch's OAuth form to grant a token, instead of using the CLI.

The preferred way of authenticating is to use this flow.  At minimum, a clientId is required

```
var credentials = TwitchCredentials.new()
credentials.client_id = "my-client-id"

await Tmi.get_node("OAuth").login(credentials)
```

When user name and channel are not specified on the TwitchCredentials, we will assume the values from the OAuth session's authenticated user.

The library is capable of performing Implicit Grant (recommended) by just supplying the clientId, as well as Code Grant when clientSecret is also provided.

For security purposes, including client secrets in your application are generally not recommended.  Use the Implicit Grant flow when possible.  Code Grants, however, do have their advantage for long running applications.  Namely the ability to refresh tokens easily in addition to them having a longer lifespan.

### Supplying a token

If you would rather supply an existing long-lived token, you can create TwitchCredentials using a token you made using the CLI.  This bypasses the requirement of tmi.gd launching a local httpserver for oauth callback and manual refreshing.

### From Project Settings

The following settings need to be defined in your Project
```
application\tmi\client_id
application\tmi\client_secret
```

It's generally not recommended to do this if you are including the client_secret, except for personal or private projects as the credentials will appear in your repository history.

Most users will use this approach because the projects are used for private personal purposes and the risk is non-existant.


### From Env

Credentials can be loaded directly from the ENV using the following variables

```
TWITCH_CLIENT_ID
TWITCH_CLIENT_SECRET
```

Alternatively if you wish to use CLI tokens instead of requiring auth

```
TWITCH_TOKEN
TWITCH_REFRESH_TOKEN
```

### From a JSON file

You can load credentials from a json file or string.

```
{
    "client_id": string,
    "client_secret": string,
}
```

If your file is encryted for security purposes, you may provide a decrypting key to the loader.  We use FileAccess.open_encrypted behind the scenes for you.

### Directly

If you decide to initialize using manual methods as described in Advanced Topics, you may assign credentials directly in the Editor or Scripting.

Please note that these methods are also considered less secure because the values will be saved as plain text in your repository.
