# tmi.gd

homebrewed twitch integration for use in Godot games and applications

## Why yet another twitch integration library

[Gift](https://github.com/issork/gift) already exists and it does a pretty good job.  If you're looking to just dive into integration with your games, it's sufficient and I highly recommend just grabbing that.

Simply, the reason for this implementation is personal.
I wanted to replace my overlays written in HTML/CSS+JS for OBS in Godot for fun.  These Godot overlays are included in the project for demonstration purposes of the addon.
This brought with it plenty of additional requirements that either aren't suitable for Gift, and Gift's architecture isn't elegant for extending and fast iteration.

The name comes from [tmi.js](https://tmijs.com/), which itself is named after [Twitch's IRC messaging interface](https://dev.twitch.tv/docs/irc/)

## What's unique about tmi.gd

- IRC chat messages are preparsed and supplied as bbcode
- Animated Emotes are supported (requires imagemagick on your PATH)
- Rich profile information and images are fetched for chatters through Twitch API
- [Pronouns](http://pronouns.alejo.io/) support for profiles
- Support for additional emotes from [7tv](https://7tv.app) and [BetterTTV](https://betterttv.com/)
- Automatic token refreshing
