// Read + write the desktop wallpaper in one process.
// Replaces two ~100ms `osascript`/System Events round-trips with ~20ms of NSWorkspace.
//
//   wallpaper-helper black <state-dir>    remember current wallpaper, go black
//   wallpaper-helper restore <state-dir>  put back the remembered wallpaper
//   wallpaper-helper current              print current wallpaper path

import AppKit

let args = CommandLine.arguments
guard args.count >= 2 else { FileHandle.standardError.write("usage: wallpaper-helper black|restore <state-dir> | current\n".data(using: .utf8)!); exit(2) }
let ws = NSWorkspace.shared

func currentURL() -> URL? {
    NSScreen.main.flatMap { ws.desktopImageURL(for: $0) }
}

func setAll(_ url: URL) {
    let opts: [NSWorkspace.DesktopImageOptionKey: Any] = [
        .imageScaling: NSImageScaling.scaleAxesIndependently.rawValue,
        .allowClipping: true,
    ]
    for screen in NSScreen.screens {
        try? ws.setDesktopImageURL(url, for: screen, options: opts)
    }
}

switch args[1] {
case "current":
    print(currentURL()?.path ?? ""); exit(currentURL() == nil ? 1 : 0)

case "black":
    guard args.count >= 3 else { exit(2) }
    let dir = URL(fileURLWithPath: args[2])
    let black = dir.appendingPathComponent("black.png")
    let last = dir.appendingPathComponent("last-wallpaper")
    // Never record black as "the last real wallpaper".
    if let cur = currentURL(), cur.standardizedFileURL != black.standardizedFileURL {
        try? cur.path.write(to: last, atomically: true, encoding: .utf8)
    }
    setAll(black)

case "restore":
    guard args.count >= 3 else { exit(2) }
    let dir = URL(fileURLWithPath: args[2])
    guard let saved = try? String(contentsOf: dir.appendingPathComponent("last-wallpaper"), encoding: .utf8)
        .trimmingCharacters(in: .whitespacesAndNewlines), !saved.isEmpty,
        FileManager.default.fileExists(atPath: saved) else { exit(0) }
    setAll(URL(fileURLWithPath: saved))

default:
    exit(2)
}
