//
//  Connectivity.swift
//  Meetup Chat
//
//  Created by Daniel Thorpe on 19/08/2014.
//  Copyright (c) 2014 @danthorpe. All rights reserved.
//

 import Foundation
 import MultipeerConnectivity

 typealias UserIdentifier = String
 typealias MultipeerServiceType = String

 class Connection: NSObject {

    let serviceType: MultipeerServiceType
    let userId: UserIdentifier

    init(service: MultipeerServiceType, userIdentifier: UserIdentifier) {

        userId = userIdentifier
        serviceType = service
        super.init()
        debug("created connection for \(userId)")
    }
 }

 extension Connection: MCNearbyServiceAdvertiserDelegate {

    func advertiser(advertiser: MCNearbyServiceAdvertiser!, didNotStartAdvertisingPeer error: NSError!) {
        debug("didNotStartAdvertisingPeer, \(error)")
    }

    func advertiser(advertiser: MCNearbyServiceAdvertiser!, didReceiveInvitationFromPeer peerID: MCPeerID!, withContext context: NSData!, invitationHandler: ((Bool, MCSession!) -> Void)!) {
        debug("received invitation from peer: \(peerID)")
    }

 }

 extension Connection: MCNearbyServiceBrowserDelegate {

    func browser(browser: MCNearbyServiceBrowser!, didNotStartBrowsingForPeers error: NSError!) {
        debug("didNotStartBrowsingForPeers, \(error)")
    }

    func browser(browser: MCNearbyServiceBrowser!, foundPeer peerID: MCPeerID!, withDiscoveryInfo info: [NSObject : AnyObject]!) {
        debug("foundPeer: \(peerID.displayName) discoveryInfo: \(info)")
    }

    func browser(browser: MCNearbyServiceBrowser!, lostPeer peerID: MCPeerID!) {
        debug("lost peer: \(peerID.displayName)")
    }
 }

 extension Connection: MCSessionDelegate {

    func session(session: MCSession!, peer peerID: MCPeerID!, didChangeState state: MCSessionState) {
        debug("\(__FUNCTION__) peer: \(peerID.displayName) state: \(state)")
    }

    func session(session: MCSession!, didReceiveData data: NSData!, fromPeer peerID: MCPeerID!) {
        debug("\(__FUNCTION__) received \(data.length) bytes from peer: \(peerID.displayName)")
    }

    func session(session: MCSession!, didReceiveStream stream: NSInputStream!, withName streamName: String!, fromPeer peerID: MCPeerID!) {
        debug("\(__FUNCTION__) received stream named: \(streamName) from peer: \(peerID.displayName)")
    }

    func session(session: MCSession!, didStartReceivingResourceWithName resourceName: String!, fromPeer peerID: MCPeerID!, withProgress progress: NSProgress!) {
        debug("\(__FUNCTION__) start receiving resource named: \(resourceName) from peer: \(peerID.displayName)")
    }

    func session(session: MCSession!, didFinishReceivingResourceWithName resourceName: String!, fromPeer peerID: MCPeerID!, atURL localURL: NSURL!, withError error: NSError!) {
        debug("\(__FUNCTION__) finished receiving resource named: \(resourceName) from peer: \(peerID.displayName)")
    }

 }

 public func debug(message: @autoclosure () -> String) {
    #if !NDEBUG
        println("->> \(message())")
    #endif
 }


