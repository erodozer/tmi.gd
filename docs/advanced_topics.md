# Advanced Topics

## Customizing Tmi features

If you wish to have more customization over Tmi instead of using the supplied singleton, you have multiple options of doing so.  You also do not need to have it initialized as an application level singleton at all if that is not desired.  The class and its dependencies are written to allow it to be initialized locally where needed, or to even support multiple clients.

It is generally recommended to add at minimal the TmiTwitchService because it provides the calls for fetching Emote images and Profile Image lookups.

### Using the Editor

Tmi is designed around scene composition, so it's natural to define an instance using Godot's editor.  This allows you to create a prefab scene with only the features you want.  You can use your prefab anywhere you need it, or even as a singleton in place of the one provided by the library.

The top level Node of the scene should have the `tmi.gd` script attached to it.  All desired TmiServices should be direct children of the top-level node,  TmiServices are typically also just basic Nodes with their associated script attached.

By using the editor, you can also assign a predefined Credentials configuration directly instead of setting it in your application's startup.  Many services also have configuration variables exported to the editor, so you may set and toggle them visually.

### Initializing Programmatically

If you like to keep initialization in one place, or like to toggle features through project or export settings, it may be more desireable to initialize a client programatically.

Take note that TmiServices are defined as just scripts, so you must first instantiate a Node and attach the script to it.

```gdscript
var tmi = Tmi.new()
var twitch_api = TmiTwitchService.new()
twitch_api.include_profile_images = false # default: (true)
tmi.add_child(twitch_api)

tmi.credentials = ...
add_child(tmi)

# tmi can only be started once it's part of the scene
tmi.start()
```

## Multiple Connections

If you wish to listen to events from multiple channels, you can spawn multiple instances of Tmi in your SceneTree.  Each instance will require its own configuration and TwitchCredentials for each channel it is allowed to listen to.

## Custom Services

Tmi.gd is designed to leverage a pluggable service architecture by consisting of registered services that exist as a composition of nodes under the Tmi client.

`TmiService` is the base class of these children.  They expect to have a Tmi instance as their direct parent in the scene tree, and will automatically hold a named reference to it.

Most services connect to events on the Tmi instance in order to react upon certain changes in state.
eg. 7tvService listens for `roomstate` commands in order to prefetch new emotes.

There is also an `enrich` function that services may define to allow them to hook onto and decorate `TmiAsyncState` objects with additional data.
`TmiTwitchService` uses this to add profile images to the TmiUserState objects
