import Cocoa
import AVFoundation

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // 设置音频会话
        setupAudioSession()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }
    
    private func setupAudioSession() {
        // macOS doesn't use AVAudioSession like iOS
        // Audio permissions are handled through entitlements and system preferences
        print("音频系统已准备就绪 - macOS")
    }
}