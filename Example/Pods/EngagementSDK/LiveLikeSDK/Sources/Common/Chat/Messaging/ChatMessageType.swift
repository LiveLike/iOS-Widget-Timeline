//
//  ChatMessage.swift
//  LiveLikeSDK
//
//  Created by Cory Sullivan on 2019-02-14.
//

import Foundation
import UIKit

/// The `UserMessage` struct represents the user **message**.
@objc public class ChatMessage: NSObject {
    /// Unique message ID.
    var id: ChatMessageID

    /// Chat Room ID
    let roomID: String
    
    /// PubNub Channel Name
    let channelName: String

    /// The message
    public let message: String

    /// Sender of the **message**. This is represented by `ChatUser` struct.
    let sender: ChatUser

    public var nickname: String {
        return sender.nickName
    }

    /// The UNIX Epoch for the senders playhead position.
    let videoTimestamp: EpochTime?

    var reactions: ReactionVotes
    
    // chat cell image (avatar)
    let profileImageUrl: URL?
    
    // chat cell body image (image attachment)
    let bodyImageUrl: URL?
    
    // chat cell body image size (image attachment)
    let bodyImageSize: CGSize?
    
    // The message after it has been filtered.
    public var filteredMessage: String?
    
    // The reason(s) why a message was filtered.
    public var filteredReasons: Set<ChatFilter>
    
    // Has the message been filtered.
    public var isMessageFiltered: Bool {
        return filteredReasons.count > 0
    }

    /// The timestamp of when this message was created
    public let timestamp: Date

    public let createdAt: TimeToken

    init(
        id: ChatMessageID,
        roomID: String,
        channelName: String,
        message: String,
        sender: ChatUser,
        videoTimestamp: EpochTime?,
        reactions: ReactionVotes,
        timestamp: Date,
        profileImageUrl: URL?,
        createdAt: TimeToken,
        bodyImageUrl: URL?,
        bodyImageSize: CGSize?,
        filteredMessage: String?,
        filteredReasons: Set<ChatFilter>
    ) {
        self.id = id
        self.roomID = roomID
        self.channelName = channelName
        self.message = message
        self.sender = sender
        self.videoTimestamp = videoTimestamp
        self.reactions = reactions
        self.profileImageUrl = profileImageUrl
        self.timestamp = timestamp
        self.createdAt = createdAt
        self.bodyImageUrl = bodyImageUrl
        self.bodyImageSize = bodyImageSize
        self.filteredMessage = filteredMessage
        self.filteredReasons = filteredReasons
    }

    public override var hash: Int {
        var hasher = Hasher()
        hasher.combine(id)
        return hasher.finalize()

    }

    public override func isEqual(_ other: Any?) -> Bool {
        guard let other = other as? ChatMessage else { return false }
        return self.id == other.id
    }

}

extension ChatMessage {
    convenience init(
        from chatPubnubMessage: PubSubChatPayload,
        chatRoomID: String,
        channel: String,
        timetoken: TimeToken,
        actions: [PubSubMessageAction],
        userID: ChatUser.ID
    ) {
        let senderID = ChatUser.ID(idString: chatPubnubMessage.senderId ?? "deleted_\(chatPubnubMessage.id)")
        let chatUser = ChatUser(
            userId: senderID,
            isActive: false,
            isLocalUser: senderID == userID,
            nickName: chatPubnubMessage.senderNickname ?? "deleted_\(chatPubnubMessage.id)",
            friendDiscoveryKey: nil,
            friendName: nil
        )

        let reactions: ReactionVotes = {
            var allVotes: [ReactionVote] = []
            actions.forEach { action in
                guard action.type == MessageActionType.reactionCreated.rawValue else { return }
                let voteID = ReactionVote.ID(action.id)
                let reactionID = ReactionID(fromString: action.value)
                let reaction = ReactionVote(
                    voteID: voteID,
                    reactionID: reactionID,
                    isMine: action.sender == userID.asString
                )
                allVotes.append(reaction)
            }
            return ReactionVotes(allVotes: allVotes)
        }()

        self.init(
            id: ChatMessageID(chatPubnubMessage.id),
            roomID: chatRoomID,
            channelName: channel,
            message: chatPubnubMessage.message ?? "deleted_\(chatPubnubMessage.id)",
            sender: chatUser,
            videoTimestamp: chatPubnubMessage.programDateTime?.timeIntervalSince1970,
            reactions: reactions,
            timestamp: timetoken.approximateDate,
            profileImageUrl: chatPubnubMessage.senderImageUrl,
            createdAt: timetoken,
            bodyImageUrl: nil,
            bodyImageSize: nil,
            filteredMessage: chatPubnubMessage.filteredMessage,
            filteredReasons: chatPubnubMessage.filteredSet
        )
    }

    convenience init(
        from chatPubnubMessage: PubSubImagePayload,
        chatRoomID: String,
        channel: String,
        timetoken: TimeToken,
        actions: [PubSubMessageAction],
        userID: ChatUser.ID
    ) {
        let senderID = ChatUser.ID(idString: chatPubnubMessage.senderId)
        let chatUser = ChatUser(
            userId: senderID,
            isActive: false,
            isLocalUser: senderID == userID,
            nickName: chatPubnubMessage.senderNickname,
            friendDiscoveryKey: nil,
            friendName: nil
        )

        let reactions: ReactionVotes = {
            var allVotes: [ReactionVote] = []
            actions.forEach { action in
                guard action.type == MessageActionType.reactionCreated.rawValue else { return }
                let voteID = ReactionVote.ID(action.id)
                let reactionID = ReactionID(fromString: action.value)
                let reaction = ReactionVote(
                    voteID: voteID,
                    reactionID: reactionID,
                    isMine: action.sender == userID.asString
                )
                allVotes.append(reaction)
            }
            return ReactionVotes(allVotes: allVotes)
        }()

        self.init(
            id: ChatMessageID(chatPubnubMessage.id),
            roomID: chatRoomID,
            channelName: channel,
            message: "", // no message
            sender: chatUser,
            videoTimestamp: chatPubnubMessage.programDateTime?.timeIntervalSince1970,
            reactions: reactions,
            timestamp: timetoken.approximateDate,
            profileImageUrl: chatPubnubMessage.senderImageUrl,
            createdAt: timetoken,
            bodyImageUrl: chatPubnubMessage.imageUrl,
            bodyImageSize: CGSize(width: chatPubnubMessage.imageWidth, height: chatPubnubMessage.imageHeight),
            filteredMessage: nil,
            filteredReasons: Set()
        )
    }

}

/// The filter type that has been applied to the chat message
public enum ChatFilter: String, Codable {
    /// Catch-all type for any kind of filtering
    case filtered
    
    /// Chat message has been filtered for profanity
    case profanity
}
