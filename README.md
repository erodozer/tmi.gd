# tmi.gd

homebrewed twitch integration for use in Godot games and applications

## Why yet another twitch integration library

[Gift](https://github.com/issork/gift) already exists and it does a pretty good job.  If you're looking to just dive into integration with your games, it's sufficient and I highly recommend just grabbing that.

Simply, the reason for this implementation is personal.
I wanted to replace my overlays written in HTML/CSS+JS for OBS in Godot for fun.  As such, the feature set of this integration is largely focused on one-directional consumption and tooling valueable for Streamers.  This focus brought with it plenty of additional requirements that either aren't suitable for Gift, and Gift's architecture isn't elegant for extending and fast iteration.

The name comes from [tmi.js](https://tmijs.com/), which itself is named after [Twitch's IRC messaging interface](https://dev.twitch.tv/docs/irc/)

## What's unique about tmi.gd

- Supports using IRC or EventSub
    - automatically uses IRC for unauthenticated sessions
    - uses EventSub when credentials are supplied
- Chat messages are preparsed and supplied as bbcode
- Animated Emotes are supported (requires imagemagick on your PATH and [magick_dumps](https://github.com/erodozer/magick-dumps)
- Rich profile information and images are fetched for chatters through Twitch API
- [Pronouns](http://pronouns.alejo.io/) support for profiles
- Support for additional emotes from [7tv](https://7tv.app) and [BetterTTV](https://betterttv.com/)
- Automatic token refreshing
- Anonymous session support for clients that need IRC chat consumption without EventSub features

## Requirements
- Godot 4.x
- GodotHttpServer (optional)
- magick_dumps (optional)

## Getting Started

Tmi.gd includes a basic Scene file of a Tmi client.  For applications that require only a single connection to Tmi, you may add this file as a Singleton/Autoload to your project.  It will include all the features available out of the box for you.

On application startup, you may supply credentials to it however you like.  A convenience function is supplied to generate credentials from your project settings.

The following settings need to be defined in your Project
```
application\tmi\twitch_client_id
application\tmi\twitch_client_secret
```

```gdscript
func _ready():
  var credentials = TwitchCredentials.load_from_project_settings()

  Tmi.credentials = credentials
  Tmi.listen_to_channel("my_channel_name")
  Tmi.start()
```

For more rich examples of how to integrate Tmi into your Godot project, and alternative ways to initialize a client, please read the included documentation or sample project.
