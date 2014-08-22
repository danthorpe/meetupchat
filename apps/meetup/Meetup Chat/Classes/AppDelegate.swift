//
//  AppDelegate.swift
//  Meetup Chat
//
//  Created by Daniel Thorpe on 14/08/2014.
//  Copyright (c) 2014 @danthorpe. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
                            
    var window: UIWindow?

    func application(application: UIApplication!, didFinishLaunchingWithOptions launchOptions: NSDictionary!) -> Bool {
        let deployment = Deployment.sharedInstance()
        deployment.setApplicationIdentifier("UOSvkvq98b3kqa80OsKhnJVgJ8v5rbW1lTgxf2Pg", clientKey: "wYe8Qi8cmCzE2Be6HNsEVUnrkTM3pcbLRm1h0UCn")
        deployment.application(application, didLaunchWithOptions: launchOptions)
        return true
    }

    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        Deployment.sharedInstance().deviceDidRegisterForRemoteNotificationsWithToken(deviceToken)
    }

    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject]) {
        Deployment.sharedInstance().receivedRemoteNotificationPayload(userInfo)
    }
}

