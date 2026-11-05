# Qwentex iPhone — SwiftUI source

This is a starter native iOS app for Qwentex. It includes a chat interface, image picker, speech input, and spoken replies.

## Important: making an IPA
You cannot compile/sign a real iPhone IPA on Windows alone. Use a Mac with Xcode:
1. Open `Qwentex.xcodeproj` in Xcode (project file is included).
2. Select your Apple development Team in **Signing & Capabilities**.
3. Set a unique Bundle Identifier (e.g. `com.yourname.qwentex`).
4. Choose a connected iPhone or **Any iOS Device (arm64)**.
5. Product → Archive, then Distribute App → export/sign as appropriate.

An IPA must be signed for installation (or distributed through TestFlight/App Store). Do not trust random unsigned IPA install instructions.

## Ollama connection
The app calls an OpenAI-compatible endpoint configured in Settings. For Ollama, use:
- Base URL: `http://YOUR-MAC-OR-PC-LAN-IP:11434/v1`
- API key: `ollama` (placeholder; Ollama usually ignores it)
- Model: `qwentex`

**The iPhone cannot use `localhost` to reach Ollama on your Windows PC.** Both devices need the same network, Ollama must listen on the LAN, and Windows Firewall must allow port 11434. Never expose Ollama directly to the public internet.

## Included
- Native SwiftUI chat UI
- Chat text + conversation context
- Photo picker (sends image as base64 in OpenAI-compatible chat request)
- Speech recognition input (permission required)
- Text-to-speech responses
- Settings for endpoint/model
- Basic local conversation persistence

This is a starter project, not a production-ready App Store release. Test permissions/networking on a real device.
