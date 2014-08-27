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

 let MeetupChatService: MultipeerServiceType = "meetup-chat"

 let ConnectedPeersDidChangeNotificationName = "ConnectedPeersDidChangeNotificationName"
 let ConnectedPeersDidSendDataNotificationName = "ConnectedPeersDidSendDataNotificationName"
 let ConnectedPeersDidReceiveDataNotificationName = "ConnectedPeersDidReceiveDataNotificationName"

 enum Result<T> {
    case Error(NSErrorPointer)
    case Success( @autoclosure () -> T)
 }

 class PeerConnectionStatus {
    let peer: UserIdentifier
    let status: Connection.Status
    init(peer peer_: UserIdentifier, status status_: Connection.Status) {
        peer = peer_
        status = status_
    }
 }

 protocol ConnectionDelegate: class {
    func connection(connection: Connection, didReceiveData data: NSData, fromPeer peer: UserIdentifier)
    func connection(connection: Connection, peer: UserIdentifier, didChangeStatus status: Connection.Status)
 }

 class Connection: NSObject {

    let serviceType: MultipeerServiceType
    let userId: UserIdentifier

    let me: MCPeerID
    let session: MCSession
    let advertiser: MCNearbyServiceAdvertiser
    let browser: MCNearbyServiceBrowser

    weak var delegate: ConnectionDelegate?

    enum Status {
        case Disconnected
        case Advertising
        case Connected
    }
    var status: Status = .Disconnected

    init(service: MultipeerServiceType, userIdentifier: UserIdentifier = UserIdentifier.defaultIdentifier()) {

        userId = userIdentifier
        serviceType = service

        me = MCPeerID(displayName: userId)
        session = MCSession(peer: me)
        advertiser = MCNearbyServiceAdvertiser(peer: me, discoveryInfo: nil, serviceType: serviceType)
        browser = MCNearbyServiceBrowser(peer: me, serviceType: serviceType)
        super.init()
        session.delegate = self
        advertiser.delegate = self
        browser.delegate = self
        debug("created connection for \(userId)")
    }

    func start() {
        debug("will start browsing for peers...")
        browser.startBrowsingForPeers()
        debug("will start advertising...")
        advertiser.startAdvertisingPeer()
    }

    func broadcast(data: NSData?, completion: (Result<NSData>) -> ()) {
        if let data = data {
            var error: NSErrorPointer = nil
            if !session.sendData(data, toPeers: session.connectedPeers, withMode: .Reliable, error: error) {
                completion(Result.Error(error))
            }
            else {
                completion(Result.Success(data))
            }
        }
    }

 }

 extension Connection: MCNearbyServiceAdvertiserDelegate {

    func advertiser(advertiser: MCNearbyServiceAdvertiser!, didNotStartAdvertisingPeer error: NSError!) {
        debug("didNotStartAdvertisingPeer, \(error)")
    }

    func advertiser(advertiser: MCNearbyServiceAdvertiser!, didReceiveInvitationFromPeer peerID: MCPeerID!, withContext context: NSData!, invitationHandler: ((Bool, MCSession!) -> Void)!) {
        debug("received invitation from peer: \(peerID)")
        invitationHandler(true, session)
    }

 }

 extension Connection: MCNearbyServiceBrowserDelegate {

    func browser(browser: MCNearbyServiceBrowser!, didNotStartBrowsingForPeers error: NSError!) {
        debug("didNotStartBrowsingForPeers, \(error)")

    }

    func browser(browser: MCNearbyServiceBrowser!, foundPeer peerID: MCPeerID!, withDiscoveryInfo info: [NSObject : AnyObject]!) {
        debug("foundPeer: \(peerID.displayName) discoveryInfo: \(info)")
        browser.invitePeer(peerID, toSession: session, withContext: nil, timeout: 30)
    }

    func browser(browser: MCNearbyServiceBrowser!, lostPeer peerID: MCPeerID!) {
        debug("lost peer: \(peerID.displayName)")
    }
 }

 extension MCSessionState {
    func status() -> Connection.Status {
        switch self {
            case .NotConnected:
                return .Disconnected
            case .Connecting:
                return .Advertising
            case .Connected:
                return .Connected
        }
    }
 }

 extension Connection: MCSessionDelegate {

    func session(session: MCSession!, peer peerID: MCPeerID!, didChangeState state: MCSessionState) {
        delegate?.connection(self, peer: peerID.displayName, didChangeStatus: state.status())
    }

    func session(session: MCSession!, didReceiveData data: NSData!, fromPeer peerID: MCPeerID!) {
        delegate?.connection(self, didReceiveData: data, fromPeer: peerID.displayName)
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

 extension UserIdentifier {
    static func random() -> UserIdentifier {
        return NSUUID().UUIDString
    }
 }

 protocol WireFormat: class {
    typealias PayloadType
    func toBinary() -> NSData?
    class func fromBinary(data: NSData) -> PayloadType
 }

 protocol NetworkPayload { }

 protocol HandlerFactory: class {
    typealias PayloadType: NetworkPayload
    typealias ObjectType

    class func handler(completion: ((Result<ObjectType>) -> ())) -> Handler<PayloadType, ObjectType>
 }

 class Network {

    typealias HandlerKey = String
    class BaseHandler {
        let token: HandlerKey

        init() {
            token = NSUUID().UUIDString
        }
        func processNetworkMessage(payload: NetworkPayload) {
            assert(true, "Subclass should implement this.")
        }
    }

    struct HandleContainer {
        let handler: BaseHandler
    }

    class Service {
        let connection = Connection(service: MeetupChatService)
        var handlers = Dictionary<HandlerKey, HandleContainer>()

        init() {
            connection.delegate = self
            connection.start()
        }

        func addNetworkMessageHandler<T,U>(handler: Handler<T,U>) -> HandlerKey {
            let key = handler.token
            handlers.updateValue(HandleContainer(handler: handler), forKey: key)
            return key
        }

        func removeNetworkMessageHandler(key: HandlerKey) {
            handlers.removeValueForKey(key)
        }

        func broadcast<T>(message: T, completion: ((Result<T>) -> ())? = nil) {
            var broadcast = MCMCBroadcast()
            switch message {
                case is MCMCTextMessage:
                    (message as MCMCTextMessage).originator = connection.userId
                    broadcast.textMessage = message as MCMCTextMessage
                default:
                break
            }

            var frame = MCMCDataFrame()
            frame.broadcast = broadcast

            connection.broadcast(frame.toBinary()) { [weak self] (result) -> () in
                if var completion = completion {
                    switch result {
                        case .Success(let data):
                            completion(Result<T>.Success(message))
                        case .Error(let errorPointer):
                            completion(Result<T>.Error(errorPointer))
                    }
                }
            }
        }

    }
 }

 extension Network.Service: ConnectionDelegate {

    func connection(connection: Connection, didReceiveData data: NSData, fromPeer peer: UserIdentifier) {
        let payload = MCMCDataFrame.fromBinary(data)
        for container in handlers.values {
            container.handler.processNetworkMessage(payload)
        }
    }

    func connection(connection: Connection, peer: UserIdentifier, didChangeStatus status: Connection.Status) {
//        let payload = PeerConnectionStatus(peer: peer, status: status)
//        for container in handlers.values {
//            container.handler.processNetworkMessage(payload)
//        }
    }
 }

 class Handler<T: NetworkPayload, U>: Network.BaseHandler {
    var mapper: (payload: T) -> Result<U>?
    var completion: (Result<U>) -> ()

    init(mapper mapper_: ((payload: T) -> (Result<U>?)), completion completion_: ((Result<U>) -> ())) {
        mapper = mapper_
        completion = completion_
        super.init()
    }

    override func processNetworkMessage(payload: NetworkPayload) {
        if let result: Result<U> = mapper(payload: payload as T) {
            completion(result)
        }
    }

 }

 extension MCMCTextMessage: HandlerFactory {
    typealias ObjectType = MCMCTextMessage
    typealias PayloadType = MCMCDataFrame

    class func handler(completion: ((Result<MCMCTextMessage>) -> ())) -> Handler<MCMCDataFrame, MCMCTextMessage> {
        return Handler(mapper: { (payload: MCMCDataFrame) -> Result<MCMCTextMessage>? in
            if payload.broadcastIsSet() {
                if payload.broadcast.textMessageIsSet() {
                    return .Success(payload.broadcast.textMessage)
                }
            }
            return nil
        }, completion: completion)
    }

    func broadcast(network: Network.Service, completion: (Result<MCMCTextMessage>) -> ()) {
        network.broadcast(self) { [weak self] (innerResult: Result<MCMCTextMessage>) -> () in
            completion(innerResult)
        }
    }
 }

 extension MCMCDataFrame: NetworkPayload, WireFormat {
    typealias PayloadType = MCMCDataFrame
    func toBinary() -> NSData? {
        var memory = TMemoryBuffer()
        let proto = TBinaryProtocol(transport: memory)
        write(proto)
        var buffer = memory.getBuffer()
        return buffer
    }

    class func fromBinary(data: NSData) -> MCMCDataFrame {
        var memory = TMemoryBuffer(data: data)
        let proto = TBinaryProtocol(transport: memory)
        var frame = MCMCDataFrame()
        frame.read(proto)
        return frame
    }
 }


 extension UserIdentifier {
    static func defaultIdentifier() -> UserIdentifier {
        let deviceName = UIDevice.currentDevice().name
        return deviceName
    }
 }


 func debug(message: @autoclosure () -> String) {
    #if !NDEBUG
        println("->> \(message())")
    #endif
}

