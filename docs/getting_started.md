# Getting Started

## About Credentials and Tokens

Twitch uses OAuth tokens for EventSub and its REST API.
Tmi.gd is capable of requesting and autorefreshing tokens on your behalf when provided a client id and secret.

If you do not use Twitch OAuth Tokens, you will only have access to messages from IRC.  Messages will also be missing Twitch API provided extended profile information, such as Profile Images.

## Creating credentials

### Local OAuth

Fetching the initial OAuth token using clientId and clientSecret requires manual user validation.  This is normally provided through the twitch CLI when requesting a new token and authorizing with the browser popup.

If your project includes [godottpd](https://github.com/deep-entertainment/godottpd), Tmi.gd is capable of performing the same flow.  It provides a request for a token with all required scopes for you, and upon callback to localhostThis allows you to use a simple web interface and twitch's OAuth form to grant a token, instead of using the CLI

### Supplying a token

If you would rather supply an existing long-lived token, you can create TwitchCredentials using a token you made using the CLI.  This bypasses the requirement of tmi.gd launching a local httpserver for oauth callback.

This method is required if you choose not to include GodotHttpServer in your project.


### From Project Settings

Since credentials are secrets, it's generally not recommended to do this except for personal or private projects as the credentials will appear in your repository history.

Most users will use this approach because the projects are used for private personal purposes and the risk is non-existant.

The following settings need to be defined in your Project
```
application\tmi\twitch_client_id
application\tmi\twitch_client_secret
```

### From Env

Credentials can be loaded directly from the ENV using the following variables

```
TWITCH_CLIENT_ID
TWITCH_CLIENT_SECRET
```

Alternatively 

```
TWITCH_TOKEN
TWITCH_REFRESH_TOKEN
```

### From a JSON file

You can load credentials from a json file or string.

```
{
    "twitch_client_id": string,
    "twitch_client_secret": string,

    "twitch_token": string,
    "twitch_refresh_token": string
}
```

If your file is encryted for security purposes, you may provide a decrypting key to the loader.  We use FileAccess.open_encrypted behind the scenes for you.

### Directly

If you decide to initialize using manual methods as described in Advanced Topics, you may assign credentials directly in the Editor or Scripting.

Please note that these methods are also considered less secure because the values will be saved as plain text in your repository.
