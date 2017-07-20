//
//  AppDelegate.swift
//  ApplicationLogger
//
//  Created by Paul McCartney on 2017/07/07.
//  Copyright © 2017年 shiba. All rights reserved.
//

import Cocoa
import AppAuth
import GTMAppAuth
import ServiceManagement

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    let AUTO_LAUNCH_KEY: String = "autoLaunch"
    
    @IBOutlet var statusMenu:   NSMenu? = NSMenu()
    var statusItem:             NSStatusItem = NSStatusItem()
    
    var currentAuthorizationFlow: OIDAuthorizationFlowSession? = nil

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        setupStatusItem()
        enableAutoLaunch()
        let appleEventManager = NSAppleEventManager.shared()
        appleEventManager.setEventHandler(self,
                                          andSelector: #selector(self.handleGetURLEvent(event:replyEvent:)),
                                          forEventClass: AEEventClass(kInternetEventClass),
                                          andEventID: AEEventID(kAEGetURL))
        let preferencesWindowController = PreferencesWindowController.sharedController
        preferencesWindowController.startLogging()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    // 自動ログイン
    func enableAutoLaunch() {
        let ud = UserDefaults.standard
        let isAutoLaunch = ud.bool(forKey: AUTO_LAUNCH_KEY)
        if !isAutoLaunch {
            let appBundleIdentifier = "com.shiba.ApplicationLoggerHelper"
            if SMLoginItemSetEnabled(appBundleIdentifier as CFString, true) {
                ud.set(true, forKey: AUTO_LAUNCH_KEY)
                print("Success to add login item")
            } else {
                ud.set(false, forKey: AUTO_LAUNCH_KEY)
                print("Faild to add login item")
            }
            ud.synchronize()
        }
    }
    
    func setupStatusItem() {
        let systemStatusBar: NSStatusBar = NSStatusBar.system()
        statusItem = systemStatusBar.statusItem(withLength: NSVariableStatusItemLength)
        statusItem.highlightMode = true
        statusItem.image = NSImage(named: "AppIcon")
        statusItem.menu = self.statusMenu
    }

    @IBAction func openPreferences(sender: NSMenuItem) {
        let preferencesWindowController: PreferencesWindowController = PreferencesWindowController.sharedController
        preferencesWindowController.showWindow(sender)
    }
    
    func handleGetURLEvent(event: NSAppleEventDescriptor, replyEvent: NSAppleEventDescriptor) {
        let urlString = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue
        let url = URL(string: urlString!)
        currentAuthorizationFlow?.resumeAuthorizationFlow(with: url!)
    }
}

