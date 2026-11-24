# Yoob for LiveKit (iOS)

Render a LiveKit voice agent as a Yoob character on the iPhone: the agent's audio drives the face on the device, so there is no avatar server and no video stream. This is a companion package to the Yoob iOS SDK ([yoob-ios-sdk-spm](https://github.com/Yoob-com/yoob-ios-sdk-spm), 0.7.5 or later); it's separate so apps that don't use LiveKit never download it.

```swift
.package(url: "https://github.com/Yoob-com/yoob-ios-livekit", from: "0.2.0")
```

LiveKit plays the agent's voice with its own echo cancellation, and the character follows the same audio. Requires
iOS 18 and Xcode 26 or later, like the Yoob SDK (LiveKit Swift SDK 2.17.0).

```swift
import LiveKit
import Yoob
import YoobLiveKit

let session = YoobLiveKitSession(avatar: avatar, room: Room())
try await session.start(url: liveKitURL, token: token)   // token from your backend; publishes the microphone
// session.state (.connecting, .listening, .thinking, .speaking, .ended), .userTranscript and
// .assistantTranscript are observable.
try await session.setMicrophoneEnabled(false)            // mute
await session.stop()                                     // disconnects if start() connected
```

Pass no `url` to use a room you already connected. The session follows the first agent participant in the room
(`options.agentIdentity` picks one) and reads captions from the agent's `lk.transcription` text streams (turn
`options.transcriptions` off if your app handles that topic itself).

- **Replies.** LiveKit Agents publishes the agent's state in the `lk.agent.state` attribute. A reply starts when the
  agent is `speaking` and its voice is audible, and ends when it leaves `speaking`; if the voice was still sounding
  then (the user interrupted), the face stops as soon as the audio already on its way does. Agents without the
  attribute are split on 600 ms of silence (`options.silenceGate`).
- **Sync.** LiveKit hands the session each 10 ms of audio as the audio device takes it, so the listener hears it one
  output latency later. The session measures that from the audio session (`outputLatency + ioBufferDuration`) at the
  start of each reply. Set `options.outputLatency` to fix it, or nudge the lips with `options.syncOffset` (positive is
  later), for example for Bluetooth headphones.

`YoobLiveKit` pins LiveKit Swift 2.17.0, which needs Xcode 16.3 or later. Swift Package Manager still downloads
LiveKit and its WebRTC binary (about 185 MB) when it resolves this package, even for apps that only use `Yoob`;
nothing from it is built or linked into those apps.

## With livekit-plugins-yoob on the agent

An agent running `yoob.AvatarSession` from the Python package `livekit-plugins-yoob` announces its character and opens
Yoob sessions for the people in the call (with its own key), so the app needs no Yoob backend route:

```swift
try await room.connect(url: liveKitURL, token: token)
let agent = try await YoobAgentAvatar.wait(in: room)      // its character, and sessions through it
let avatar = YoobAvatar(agent.source, version: agent.version)
let session = YoobLiveKitSession(avatar: avatar, room: room)
try await session.start()
```

`wait(in:)` throws `YoobError.network` when no agent announces a character within `timeout` (30 s); a refused session
keeps Yoob's reason (`.unauthorized`, `.outOfCredit`).

## License

Apache-2.0.
