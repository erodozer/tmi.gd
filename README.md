# tmi.gd

homebrewed twitch integration for use in Godot games and applications

## Why yet another twitch integration library

[Gift](https://github.com/issork/gift) already exists and it does a pretty good job.  If you're looking to just dive into integration with your games, it's sufficient and I highly recommend just grabbing that.

Simply, the reason for this implementation is personal.
I wanted to replace my overlays written in HTML/CSS+JS for OBS in Godot for fun.  As such, the feature set of this integration is largely focused on one-directional consumption and tooling valueable for Streamers.  This focus brought with it plenty of additional requirements that aren't suitable for Gift, and at the time I found Gift's architecture wasn't elegant for extending and fast iteration.

As this integration evolved initially from my own needs, it may not be fully comprehensive of the Twitch event API.
If you encounter a portion of the Twitch event API not covered yet covered by that you wish to use, feel free to request it or contribute a binding through a pull request for review.

It is not recommended to use tmi.gd for creating bots that require writing message back to chat or modifying stream state with the Twitch API.  This functionality is intentionally not supported out of the box.

The name of the project comes from [tmi.js](https://tmijs.com/), which itself is named after [Twitch's IRC messaging interface](https://dev.twitch.tv/docs/irc/)

## What's unique about tmi.gd

- Supports using IRC or EventSub
    - automatically uses IRC for unauthenticated sessions
    - uses EventSub when credentials are supplied
- Chat messages are preparsed and supplied as bbcode
- support for Animated Emotes*
- Rich profile information and images fetched for chatters through Twitch API
- [Pronouns](http://pronouns.alejo.io/) support for profiles
- Support for additional emotes
    - [7tv](https://7tv.app)
    - [BetterTTV](https://betterttv.com/)
- Automatic token refreshing
- Extensible interface and patterns, allowing for easily integrating third-party services and data with Twitch user state and events

## Requirements
- Godot 4.x
- [magick_dumps](https://github.com/erodozer/magick-dumps) (optional, necessary for animated emotes)

## Getting Started

Tmi.gd includes a basic Scene file of a Tmi client.  For applications that require only a single connection to Tmi, you may add this file as a Singleton/Autoload to your project.  It will include standard features for streaming available out of the box for you.

On application startup, you may supply credentials to it however you like.  A convenience function is supplied to generate credentials from your project settings.

The following settings need to be defined in your Project
```
application\tmi\client_id
```

```gdscript
func _ready():
  var credentials = TwitchCredentials.load_from_project_settings()

  Tmi.login(credentials)
```

The EventSub connection will begin automatically after authentication is successful, listening to events from the channel associated with the authenticated user.

For more rich examples of how to integrate Tmi into your Godot project, and alternative ways to initialize a client, please read the [included documentation](/docs/getting_started.md) or view the sample project.
