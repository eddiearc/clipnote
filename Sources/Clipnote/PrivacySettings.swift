import AppKit

enum PrivacySettings {
    /// 打开系统设置中的提醒事项隐私页；失败则退回设置应用本身。
    static func openReminders() {
        let candidates = [
            "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Reminders"
        ]
        for string in candidates {
            if let url = URL(string: string), NSWorkspace.shared.open(url) {
                return
            }
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }

    static func openRemindersApp() {
        let url = URL(fileURLWithPath: "/System/Applications/Reminders.app")
        NSWorkspace.shared.open(url)
    }
}
