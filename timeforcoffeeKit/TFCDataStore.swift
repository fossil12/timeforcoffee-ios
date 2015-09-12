//
//  TFCDataStore.swift
//  timeforcoffee
//
//  Created by Christian Stocker on 23.03.15.
//  Copyright (c) 2015 Christian Stocker. All rights reserved.
//

import Foundation
import WatchConnectivity

public class TFCDataStore: NSObject, WCSessionDelegate {

    public class var sharedInstance: TFCDataStore {
        struct Static {
            static let instance: TFCDataStore = TFCDataStore()
        }
        return Static.instance
    }

    let lockQueue = dispatch_queue_create("group.ch.opendata.timeforcoffee.notificationLock", DISPATCH_QUEUE_SERIAL)

    private let userDefaults: NSUserDefaults? = NSUserDefaults(suiteName: "group.ch.opendata.timeforcoffee")
    private let keyvaluestore: NSUbiquitousKeyValueStore? = NSUbiquitousKeyValueStore.defaultStore()
    private var notificationObserver: AnyObject?

    func setObject(anObject: AnyObject?, forKey: String, withWCTransfer: Bool) {
        userDefaults?.setObject(anObject , forKey: forKey)
        keyvaluestore?.setObject(anObject, forKey: forKey)
        if #available(iOS 9, *) {
            if (withWCTransfer != false) {
                let applicationDict = [forKey: anObject!]
                WCSession.defaultSession().transferUserInfo(applicationDict)
            }
        }
    }

    func setObject(anObject: AnyObject?, forKey: String) {
        self.setObject(anObject, forKey: forKey, withWCTransfer: true)
    }

    func objectForKey(forKey: String) -> AnyObject? {
        return userDefaults?.objectForKey(forKey)
    }

    func removeObjectForKey(forKey: String) {
        self.removeObjectForKey(forKey, withWCTransfer: true)
    }

    func removeObjectForKey(forKey: String, withWCTransfer: Bool) {
        userDefaults?.removeObjectForKey(forKey)
        keyvaluestore?.removeObjectForKey(forKey)
        if #available(iOS 9, *) {
            if (withWCTransfer != false) {
                let applicationDict = ["___remove___": forKey]
                WCSession.defaultSession().transferUserInfo(applicationDict)
            }
        }
    }

    public func synchronize() {
        userDefaults?.synchronize()
        keyvaluestore?.synchronize()
    }

    public func registerWatchConnectivity() {
        if #available(iOS 9, *) {
            if (WCSession.isSupported()) {
                let session = WCSession.defaultSession()
                session.delegate = self
                session.activateSession()
            }
        }
    }

    public func registerForNotifications() {
        dispatch_sync(lockQueue) {
            if (self.notificationObserver != nil) {
                return
            }
            self.notificationObserver = NSNotificationCenter.defaultCenter().addObserverForName("NSUbiquitousKeyValueStoreDidChangeExternallyNotification", object: self.keyvaluestore, queue: nil, usingBlock: { (notification: NSNotification!) -> Void in
                let userInfo: NSDictionary? = notification.userInfo as NSDictionary?
                let reasonForChange: NSNumber? = userInfo?.objectForKey(NSUbiquitousKeyValueStoreChangeReasonKey) as! NSNumber?
                if (reasonForChange == nil) {
                    return
                }
                NSLog("got icloud sync")

                let reason = reasonForChange?.integerValue
                if ((reason == NSUbiquitousKeyValueStoreServerChange) ||
                    (reason == NSUbiquitousKeyValueStoreInitialSyncChange)) {
                        let changedKeys: [String]? = userInfo?.objectForKey(NSUbiquitousKeyValueStoreChangedKeysKey) as! [String]?
                        if (changedKeys != nil) {
                            for (key) in changedKeys! {
                                // legacy, can be removed later
                                if (key == "favoriteStations") {
                                    self.keyvaluestore?.removeObjectForKey("favoriteStations")
                                } else {
                                    self.userDefaults?.setObject(self.keyvaluestore?.objectForKey(key), forKey: key)
                                    if (key == "favorites2") {
                                        TFCFavorites.sharedInstance.repopulateFavorites()
                                    }
                                }
                            }
                        }
                }
                
            })
        }
    }

    public func removeNotifications() {
        NSLog("removeNotifications")
        dispatch_sync(lockQueue) {
            NSLog("removeNotifications2")

            if (self.notificationObserver != nil) {
                NSNotificationCenter.defaultCenter().removeObserver(self.notificationObserver!)
                self.notificationObserver = nil
            }
        }
    }

    public func getUserDefaults() -> NSUserDefaults? {
        return userDefaults
    }

    @available(iOSApplicationExtension 9.0, *)
    public func session(session: WCSession, didReceiveUserInfo userInfo: [String : AnyObject]) {
        for (myKey,myValue) in userInfo {
            if (myKey == "___remove___") {
                if let key = myValue as? String {
                    self.removeObjectForKey(key, withWCTransfer: false)
                }
            } else {
                self.setObject(myValue, forKey: myKey, withWCTransfer: false)
            }
        }
    }


}