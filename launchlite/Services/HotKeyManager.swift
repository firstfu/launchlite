//
//  HotKeyManager.swift
//  launchlite
//
//  Created by firstfu on 2026/3/2.
//
//  全域快捷鍵管理器，使用 CGEvent Tap 攔截系統層級的鍵盤事件來觸發 Launchpad。

import Cocoa
import CoreGraphics

/// CGEvent Tap 回呼的上下文物件，儲存事件攔截器和按鍵匹配參數。
private final class HotKeyTapContext {
    var eventTap: CFMachPort?
    var modifierFlags: CGEventFlags = [.maskAlternate, .maskCommand]
    var keyCode: CGKeyCode = 0x25
    var onMatch: () -> Void = {}
}

/// CGEvent Tap 的 C 回呼函數，比對按鍵事件是否符合設定的快捷鍵組合。
private let hotKeyCallback: CGEventTapCallBack = { proxy, type, event, userInfo in
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let userInfo {
            let ctx = Unmanaged<HotKeyTapContext>.fromOpaque(userInfo).takeUnretainedValue()
            if let tap = ctx.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
        return Unmanaged.passUnretained(event)
    }

    guard type == .keyDown, let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let ctx = Unmanaged<HotKeyTapContext>.fromOpaque(userInfo).takeUnretainedValue()

    let eventKeyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
    let eventFlags = event.flags
    let relevantFlags: CGEventFlags = [.maskAlternate, .maskCommand, .maskShift, .maskControl]
    let pressedModifiers = eventFlags.intersection(relevantFlags)
    let requiredModifiers = ctx.modifierFlags.intersection(relevantFlags)

    if eventKeyCode == ctx.keyCode && pressedModifiers == requiredModifiers {
        ctx.onMatch()
        return nil // swallow the event
    }

    return Unmanaged.passUnretained(event)
}

/// 全域快捷鍵管理器，透過 CGEvent Tap 攔截系統鍵盤事件，匹配設定的快捷鍵組合以觸發 Launchpad。
@MainActor
final class HotKeyManager {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var retainedCtxPtr: UnsafeMutableRawPointer?
    private let tapContext = HotKeyTapContext()
    private let onTrigger: () -> Void

    // Default: Option(⌥) + Command(⌘) + L
    private(set) var modifierFlags: CGEventFlags = [.maskAlternate, .maskCommand]
    private(set) var keyCode: CGKeyCode = 0x25 // 'L' key

    /// 初始化快捷鍵管理器，設定觸發時的回呼函數。
    init(onTrigger: @escaping () -> Void) {
        self.onTrigger = onTrigger
        tapContext.onMatch = { [weak self] in
            Task { @MainActor in
                self?.onTrigger()
            }
        }
    }

    deinit {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let ptr = retainedCtxPtr {
            Unmanaged<HotKeyTapContext>.fromOpaque(ptr).release()
        }
    }

    // MARK: - Configuration

    /// 解析快捷鍵字串並更新修飾鍵和按鍵碼設定。
    func configure(hotkey: String) {
        let parsed = HotKeyManager.parse(hotkey: hotkey)
        self.modifierFlags = parsed.modifiers
        self.keyCode = parsed.keyCode
        tapContext.modifierFlags = parsed.modifiers
        tapContext.keyCode = parsed.keyCode
    }

    // MARK: - Start / Stop

    /// 啟動 CGEvent Tap 開始攔截鍵盤事件，需要輔助使用權限。回傳是否成功啟動。
    func start() -> Bool {
        guard eventTap == nil else { return true }

        guard checkAccessibilityPermission() else {
            requestAccessibilityPermission()
            return false
        }

        tapContext.modifierFlags = modifierFlags
        tapContext.keyCode = keyCode

        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        let ctxPtr = Unmanaged.passRetained(tapContext).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: hotKeyCallback,
            userInfo: ctxPtr
        ) else {
            Unmanaged<HotKeyTapContext>.fromOpaque(ctxPtr).release()
            return false
        }

        retainedCtxPtr = ctxPtr
        tapContext.eventTap = tap
        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    /// 停止 CGEvent Tap 並釋放相關資源。
    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            }
            if let ptr = retainedCtxPtr {
                Unmanaged<HotKeyTapContext>.fromOpaque(ptr).release()
                retainedCtxPtr = nil
            }
            tapContext.eventTap = nil
            runLoopSource = nil
            eventTap = nil
        }
    }

    // MARK: - Accessibility Permission

    /// 檢查應用程式是否已取得輔助使用（Accessibility）權限。
    func checkAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    /// 請求使用者授予輔助使用權限，顯示系統授權對話框。
    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    // MARK: - Hotkey Parsing

    /// 解析快捷鍵字串（如 "Option+Command+L"），回傳對應的修飾鍵旗標和按鍵碼。
    static func parse(hotkey: String) -> (modifiers: CGEventFlags, keyCode: CGKeyCode) {
        var modifiers: CGEventFlags = []
        var key: Character = "L"

        for char in hotkey {
            switch char {
            case "\u{2325}": // ⌥
                modifiers.insert(.maskAlternate)
            case "\u{2318}": // ⌘
                modifiers.insert(.maskCommand)
            case "\u{21E7}": // ⇧
                modifiers.insert(.maskShift)
            case "\u{2303}": // ⌃
                modifiers.insert(.maskControl)
            default:
                key = char
            }
        }

        if modifiers.isEmpty {
            modifiers = [.maskAlternate, .maskCommand]
        }

        let keyCode = keyCodeForCharacter(key)
        return (modifiers, keyCode)
    }

    /// 將字元轉換為對應的 macOS 虛擬按鍵碼（CGKeyCode）。
    private static func keyCodeForCharacter(_ char: Character) -> CGKeyCode {
        let keyMap: [Character: CGKeyCode] = [
            "A": 0x00, "S": 0x01, "D": 0x02, "F": 0x03,
            "H": 0x04, "G": 0x05, "Z": 0x06, "X": 0x07,
            "C": 0x08, "V": 0x09, "B": 0x0B, "Q": 0x0C,
            "W": 0x0D, "E": 0x0E, "R": 0x0F, "Y": 0x10,
            "T": 0x11, "1": 0x12, "2": 0x13, "3": 0x14,
            "4": 0x15, "6": 0x16, "5": 0x17, "9": 0x19,
            "7": 0x1A, "8": 0x1C, "0": 0x1D, "O": 0x1F,
            "U": 0x20, "I": 0x22, "P": 0x23, "L": 0x25,
            "J": 0x26, "K": 0x28, "N": 0x2D, "M": 0x2E,
        ]
        return keyMap[Character(char.uppercased())] ?? 0x25
    }
}
