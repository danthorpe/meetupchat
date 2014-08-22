//
//  Deployment.swift
//  Meetup Chat
//
//  Created by Daniel Thorpe on 22/08/2014.
//  Copyright (c) 2014 @danthorpe. All rights reserved.
//

import Foundation

let deployment = Deployment()

public class Deployment {

    public class func sharedInstance() -> Deployment {
        return deployment
    }

    public func setApplicationIdentifier(applicationId: String!, clientKey: String!) {
        Parse.setApplicationId(applicationId, clientKey: clientKey)
    }

    public func application(application: UIApplication!, didLaunchWithOptions launchOptions: NSDictionary?) {
        configureNotificationsForApplication(application)

        if let options = launchOptions {
            if let payload = options[UIApplicationLaunchOptionsRemoteNotificationKey] as? NSDictionary {
                receivedRemoteNotificationPayload(payload)
            }
        }
        else {
            // check for any new versions of the app
            checkForNewVersions()
        }
    }

    public func receivedRemoteNotificationPayload(payload: NSDictionary?) {
        if let payload = payload {
            // Get the rinse.repeat.build payload
            if let rrb = payload["rrb"] as? Dictionary<String, String> {
                if let manifestUrl = rrb["url"] {
                    installFromManifest(manifestUrl)
                }
            }
        }
    }

    public func deviceDidRegisterForRemoteNotificationsWithToken(deviceToken: NSData) {
        PFInstallation.currentInstallation().setDeviceTokenFromData(deviceToken)
        PFInstallation.currentInstallation().channels = channels()
        PFInstallation.currentInstallation().saveInBackground()
    }


    private func configureNotificationsForApplication(application: UIApplication!) {
        if application.respondsToSelector("registerForRemoteNotifications") {
            application.registerForRemoteNotifications()
        }
        else {
            application.registerForRemoteNotificationTypes(.Alert)
        }
    }

    private func channels() -> [String] {
        func formatChannelName(channelName: String) -> String {
            return channelName.stringByReplacingOccurrencesOfString(".", withString: "_", options: NSStringCompareOptions.CaseInsensitiveSearch, range: nil)
        }

        var bundleIdentifier: AnyObject? = NSBundle.mainBundle().infoDictionary["CFBundleIdentifier"]
        var primaryChannelName = formatChannelName(bundleIdentifier! as String)
        var channels: [String] = [ primaryChannelName ]
        #if !NDEBUG
            channels.append("beta_\(primaryChannelName)")
        #endif
        println("Channels will be: \(channels)")
        return channels
    }

    private func installFromManifest(manifest: String) {
        var url = NSURL(string: "itms-services://?action=download-manifest&url=\(manifest)")
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(NSEC_PER_SEC)), dispatch_get_main_queue()) {
            var success = UIApplication.sharedApplication().openURL(url)
        }
    }

    private func installFromBuild(build: PFObject) {
        var manifestUrl = build.objectForKey("url") as String
        installFromManifest(manifestUrl)
    }

    private func checkForNewVersions() {
        if currentBundleVersion() == 1 { return }
        fetchLatestBuild { [weak self] (result) -> () in
            if let weakSelf = self? {
                switch result {
                case .Error(let error):
                    debug("Error fetching lasted build")
                case .Result(let build):
                    if let build = build {
                        if weakSelf.isOlderThanBuild(build) {
                            weakSelf.installFromBuild(build)
                        }
                    }
                }
            }
        }
    }

    private func currentBundleVersion() -> Int {
        var bundle_version: AnyObject? = NSBundle.mainBundle().infoDictionary["CFBundleVersion"]
        if let version = bundle_version as? Int {
            return version
        }
        return 1
    }

    private func isOlderThanBuild(build: PFObject) -> Bool {
        var current = UInt8(currentBundleVersion())
        if current > 1 {
            if let bundle_version: NSNumber = build.objectForKey("bundle_version") as? NSNumber {
                return UInt8(bundle_version.integerValue) > UInt8(currentBundleVersion())
            }
        }
        return false
    }


    func fetchLatestBuild(completion: (PFObject.FetchCompletion) -> ()) {

        var query = PFQuery(className: "Build")
        query.orderByDescending("bundle_version")
        query.limit = 1

        query.findInBackground { (result) -> () in
            completion(result.latestResult())
        }
    }

    func alertToInstallNewBuild(build: PFObject) -> UIAlertController {
        let title = "Install new build"
        let applicationName = build.objectForKey("application_name") as String
        let message = "There is a new build of \(applicationName)"
        var alert = UIAlertController(title: title, message: message, preferredStyle: .Alert)
        return alert
    }

}

extension PFObject {

    public enum FetchCompletion {
        case Result(PFObject?)
        case Error(NSError)
    }

    func fetchInBackground(completion: (FetchCompletion) -> ()) {
        fetchInBackgroundWithBlock { (result, error) in
            if error != nil {
                completion(FetchCompletion.Error(error))
            }
            else {
                completion(FetchCompletion.Result(result))
            }
        }
    }
}

extension PFQuery {

    public enum FindCompletion {
        case Result([PFObject]?)
        case Error(NSError)

        func latestResult() -> PFObject.FetchCompletion {
            switch self {
            case .Error(let error):
                return .Error(error)
            case .Result(let objects):
                if let objects = objects {
                    return .Result(objects.first)
                }
            }
            return .Result(nil)
        }
    }

    func findInBackground(completion: (FindCompletion) -> ()) {
        findObjectsInBackgroundWithBlock { (objects, error) in
            if error != nil {
                completion(FindCompletion.Error(error))
            }
            else {
                completion(FindCompletion.Result(objects as? [PFObject]))
            }
        }
    }
}

func debug(message: @autoclosure () -> String) {
    #if !NDEBUG
        println("->> \(message())")
    #endif
}

