//
//  Chat.swift
//  Meetup Chat
//
//  Created by Daniel Thorpe on 25/08/2014.
//  Copyright (c) 2014 @danthorpe. All rights reserved.
//

 import Foundation

 class ChatContainer: UIViewController {

    let network = Network.Service()
    var _dataSource: ChatDataSource?
    var dataSource: ChatDataSource {
        return _dataSource!
    }

    @IBOutlet weak var toolbarView: UIView!
    @IBOutlet weak var textField: UITextField!
    @IBOutlet weak var sendButton: UIButton!

    required init(coder aDecoder: NSCoder) {
        _dataSource = ChatDataSource(network: network)
        super.init(coder: aDecoder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureController()
    }

    func configureController() {
        title = "Meetup Chat"
        navigationController.navigationBar.backgroundColor = UIColor.darkGrayColor()
        configureToolbar()
    }

    func configureToolbar() {

        view.keyboardTriggerOffset = CGRectGetHeight(toolbarView!.bounds)

        view.addKeyboardPanningWithActionHandler { [weak self] (keyboardFrameInView, isOpening, isClosing) -> Void in
            if let weakSelf = self {
                var frame = weakSelf.view.frame
                frame.size.height = CGRectGetMinY(keyboardFrameInView)
                weakSelf.view.frame = frame
            }
        }
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        dataSource.addNetworkHandlers()
    }

    override func viewDidDisappear(animated: Bool) {
        super.viewDidDisappear(animated)
        dataSource.removeNetworkHandlers()
    }

    override func prepareForSegue(segue: UIStoryboardSegue!, sender: AnyObject!) {
        if segue.identifier == "embed.chat" {
            if let chat = segue.destinationViewController as? ChatViewController {
                chat.dataSource = dataSource
            }
        }
    }

    @IBAction func sendAction(sender: AnyObject) {
        if !textField.text.isEmpty {
            let textMessage = MCMCTextMessage()
            textMessage.text = textField.text
            textMessage.broadcast(network) { [weak self] (result) -> () in
                switch result {
                case .Error(let error):
                    debug("Error sending message: \(error)")
                case .Success(let message):
                    self?.textField.text = ""
                    self?.dataSource.addMessage(textMessage)
                }
            }
        }
    }

    func didSendDataNotification(notification: NSNotification) {
        textField.text = ""
    }
 }

 class ChatDataSource: NSObject, TableViewDataSource {

    private struct InternalData {
        var items: [ChatItem] = []
    }
    private let protected = Protector(InternalData())

    let network: Network.Service
    var networkHandlers: [Network.HandlerKey] = []

    var tableView: UITableView?

    init(network network_: Network.Service) {
        network = network_
        super.init()
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "numberOfConnectedPeersDidChangeNotification:", name: ConnectedPeersDidChangeNotificationName, object: nil)
    }

    func addItem(item: ChatItem, completion: ((Int) -> ())? = nil) {
        var insertedIndex: Int?
        protected.write({ (protected) -> () in
            protected.items.append(item)
            insertedIndex = protected.items.count - 1
        }, completion: {
            if let block = completion {
                block(insertedIndex!)
            }
        })
    }

    func itemAtIndexPath(indexPath: NSIndexPath) -> ChatItem {
        return protected.read { protected in
            return protected.items[indexPath.row]
        }
    }

    func addNetworkHandlers() {

        let receivedTextMessageHandler = MCMCTextMessage.handler { [weak self] (result) in
            switch result {
                case .Success(let message):
                    self?.addMessage(message())
                default:
                    break
            }
        }
        networkHandlers.append(network.addNetworkMessageHandler(receivedTextMessageHandler))
    }

    func removeNetworkHandlers() {
        for (index: Int, key: Network.HandlerKey) in enumerate(networkHandlers) {
            network.removeNetworkMessageHandler(key)
        }
    }

    func numberOfConnectedPeersDidChangeNotification(notification: NSNotification) {
        if let userInfo = notification.userInfo as? [String: AnyObject] {
            if let peerStatus = userInfo["PeerStatus"] as? PeerConnectionStatus {
                addItemsToChat(peerStatus)
            }
        }
    }

    func addMessage(textMessage: MCMCTextMessage) {
        addItemsToChat(textMessage)
    }

    func addItemsToChat(item: ChatItem) {
        addItem(item) { [weak self] (insertedIndex) in
            var indexPath = NSIndexPath(forRow: insertedIndex, inSection: 0)
            dispatch_async(dispatch_get_main_queue()) {
                if let tableView = self?.tableView {
                    tableView.insertRowsAtIndexPaths([indexPath], withRowAnimation: UITableViewRowAnimation.Automatic)
                    tableView.scrollToRowAtIndexPath(indexPath, atScrollPosition: .Bottom, animated: true)
                }
            }
        }
    }

    func tableView(tableView: UITableView!, numberOfRowsInSection section: Int) -> Int {
        return protected.read { protected in
            return protected.items.count
        }
    }

    func tableView(tableView: UITableView!, cellForRowAtIndexPath indexPath: NSIndexPath!) -> UITableViewCell! {
        let count: Int = protected.read { protected in
            return protected.items.count
        }
        if indexPath.row < count {
            let item = itemAtIndexPath(indexPath)
            switch item {

            case is PeerConnectionStatus:
                var cell: SystemEventCell = tableView.dequeueReusableCellWithIdentifier("SystemEvent", forIndexPath: indexPath) as SystemEventCell
                cell.eventLabel.text = (item as ChatItem).primaryText
                return cell

            case is MCMCTextMessage:

                var cell: TextMessageCell = tableView.dequeueReusableCellWithIdentifier("ReceivedMessage", forIndexPath: indexPath) as TextMessageCell
                cell.nameLabel.text = (item as ChatItem).secondaryText
                cell.messageLabel.text = (item as ChatItem).primaryText

                if (item as MCMCTextMessage).isUser {
                    cell.nameLabel.textColor = UIColor(red: 0.508, green: 0.659, blue: 0.435, alpha: 1)
                }
                else {
                    cell.nameLabel.textColor = UIColor(red: 0.502, green: 0.589, blue: 0.659, alpha: 1)
                }
                return cell
            default:
                break
            }
        }
        return nil
    }
    
}

 class SystemEventCell: UITableViewCell {
    let padding = UIEdgeInsetsMake(2, 4, 2, 4)
    var eventLabel: UILabel

    override init(style: UITableViewCellStyle, reuseIdentifier: String!) {
        eventLabel = UILabel(frame: CGRectZero)
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        commonInit()
    }

    required init(coder aDecoder: NSCoder) {
        eventLabel = UILabel(frame: CGRectZero)
        super.init(coder: aDecoder)
        commonInit()
    }

    func commonInit() {
        backgroundColor = UIColor.darkGrayColor()
        eventLabel.setTranslatesAutoresizingMaskIntoConstraints(false)
        eventLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleFootnote)
        eventLabel.textAlignment = .Center
        eventLabel.textColor = UIColor.grayColor()
        contentView.addSubview(eventLabel)
        configureConstraints()
    }

    func configureConstraints() {
        var constraints: [NSLayoutConstraint] = []

        // Vertical constraints
        constraints.append(NSLayoutConstraint(item: eventLabel, attribute: .Top, relatedBy: .Equal, toItem: contentView, attribute: .Top, multiplier: 1, constant: padding.top))
        constraints.append(NSLayoutConstraint(item: contentView, attribute: .Bottom, relatedBy: .GreaterThanOrEqual, toItem: eventLabel, attribute: .Bottom, multiplier: 1, constant: padding.bottom))
        constraints.append(NSLayoutConstraint(item: contentView, attribute: .Height, relatedBy: .GreaterThanOrEqual, toItem: eventLabel, attribute: .Height, multiplier: 1, constant: 0))
        // Horizontal constraints
        constraints.append(NSLayoutConstraint(item: eventLabel, attribute: .Leading, relatedBy: .Equal, toItem: contentView, attribute: .Leading, multiplier: 1, constant: padding.left))
        constraints.append(NSLayoutConstraint(item: eventLabel, attribute: .Trailing, relatedBy: .Equal, toItem: contentView, attribute: .Trailing, multiplier: 1, constant: -padding.right))

        contentView.addConstraints(constraints)
    }
}

 class TextMessageCell: UITableViewCell {

    let padding = UIEdgeInsetsMake(2, 4, 2, 4)
    var nameLabel: UILabel
    var messageLabel: UILabel

    override init(style: UITableViewCellStyle, reuseIdentifier: String!) {
        nameLabel = UILabel(frame: CGRectZero)
        messageLabel = UILabel(frame: CGRectZero)
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        commonInit()
    }

    required init(coder aDecoder: NSCoder) {
        nameLabel = UILabel(frame: CGRectZero)
        messageLabel = UILabel(frame: CGRectZero)
        super.init(coder: aDecoder)
        commonInit()
    }

    func commonInit() {
        backgroundColor = UIColor.darkGrayColor()
        nameLabel.setTranslatesAutoresizingMaskIntoConstraints(false)
        nameLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleSubheadline)
        nameLabel.textAlignment = .Right
        nameLabel.textColor = UIColor.whiteColor()
        contentView.addSubview(nameLabel)

        messageLabel.setTranslatesAutoresizingMaskIntoConstraints(false)
        messageLabel.font = UIFont.preferredFontForTextStyle(UIFontTextStyleBody)
        messageLabel.textColor = UIColor.lightGrayColor()
        messageLabel.numberOfLines = 0
        contentView.addSubview(messageLabel)
        configureConstraints()
    }

    func configureConstraints() {
        var constraints: [NSLayoutConstraint] = []

        // Vertical constraints
        constraints.append(NSLayoutConstraint(item: messageLabel, attribute: .FirstBaseline, relatedBy: .Equal, toItem: contentView, attribute: .Top, multiplier: 1.8, constant: 30))
        constraints.append(NSLayoutConstraint(item: nameLabel, attribute: .FirstBaseline, relatedBy: .Equal, toItem: messageLabel, attribute: .FirstBaseline, multiplier: 1, constant: 0))
        constraints.append(NSLayoutConstraint(item: contentView, attribute: .Bottom, relatedBy: .GreaterThanOrEqual, toItem: messageLabel, attribute: .Bottom, multiplier: 1, constant: padding.bottom))
        constraints.append(NSLayoutConstraint(item: contentView, attribute: .Height, relatedBy: .GreaterThanOrEqual, toItem: messageLabel, attribute: .Height, multiplier: 1, constant: 0))
        // Horizontal constraints
        constraints.append(NSLayoutConstraint(item: nameLabel, attribute: .Leading, relatedBy: .Equal, toItem: contentView, attribute: .Leading, multiplier: 1, constant: padding.left))
        constraints.append(NSLayoutConstraint(item: nameLabel, attribute: .Width, relatedBy: .Equal, toItem: nil, attribute: .NotAnAttribute, multiplier: 1, constant: 110))
        constraints.append(NSLayoutConstraint(item: messageLabel, attribute: .Leading, relatedBy: .Equal, toItem: nameLabel, attribute: .Trailing, multiplier: 1, constant: padding.left))
        constraints.append(NSLayoutConstraint(item: messageLabel, attribute: .Trailing, relatedBy: .Equal, toItem: contentView, attribute: .Trailing, multiplier: 1, constant: -padding.right))

        contentView.addConstraints(constraints)
    }
 }

 protocol TableViewDataSource: UITableViewDataSource {
    var tableView: UITableView? { get set }
 }

 class ChatViewController: UITableViewController {

    var dataSource: TableViewDataSource?

    override func viewDidLoad() {
        super.viewDidLoad()
        configureController()
        configureDataSource()
    }

    func configureController() {
        title = "Meetup Chat"
        tableView.backgroundColor = UIColor.darkGrayColor()
        tableView.registerClass(SystemEventCell.self, forCellReuseIdentifier: "SystemEvent")
        tableView.registerClass(TextMessageCell.self, forCellReuseIdentifier: "ReceivedMessage")
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableViewAutomaticDimension
    }

    func configureDataSource() {
        dataSource!.tableView = tableView
        tableView.dataSource = dataSource
    }
 }

 @objc protocol ChatItem {
    var primaryText: String? { get }
    var secondaryText: String? { get }
 }

 class PeerStatusChange: ChatItem {
    let peer: String
    let status: String
    var primaryText: String? {
        return String(format: "%@ %@", peer, status)
    }

    var secondaryText: String? { return nil }

    init(peer peer_: String, status status_: String) {
        peer = peer_
        status = status_
    }
 }

 extension MCMCTextMessage: ChatItem {

    var primaryText: String? {
        return textIsSet() ? text : nil
    }

    var secondaryText: String? {
        return originatorIsSet() ? originator : nil
    }

    var isUser: Bool {
        return originatorIsSet() ? originator == UserIdentifier.defaultIdentifier() : false
    }
 }

 extension PeerConnectionStatus: ChatItem {
    var primaryText: String? {
        switch status {
            case .Connected, .Disconnected:
                return String(format: "%@ %@", peer, status.displayText())
            default:
                break
        }
        return nil
    }

    var secondaryText: String? { return nil }
 }

 extension Connection.Status {
    func displayText() -> String {
        switch self {
            case .Disconnected:
                return "left"
            case .Connected:
                return "joined"
            case .Advertising:
                return "searching"
        }
    }
 }
