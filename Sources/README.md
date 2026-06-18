# FFmpegKit Binary Artifacts

The xcframeworks in this directory are SwiftPM binary targets. They are generated
and refreshed by the `BuildFFmpeg` Swift package plugin:

```bash
swift package --disable-sandbox BuildFFmpeg
```

Run the plugin from the `FFmpegKit` package root. The plugin writes rebuilt
artifacts back to `Sources/<name>.xcframework`, which is the distribution layout
consumed by `Package.swift`.
