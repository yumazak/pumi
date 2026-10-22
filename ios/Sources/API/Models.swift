import Foundation

// The wire shapes the bridge passes through from opencode. Only the fields the
// app renders are modelled.

struct OcTime: Decodable {
    var created: Double?
    var updated: Double?
    var idle: Double?
    var viewed: Double?
}

struct OcLocation: Decodable {
    var directory: String?
}

struct OcSession: Decodable, Identifiable {
    var id: String
    var title: String?
    var agent: String?
    var projectID: String?
    var parentID: String?
    var time: OcTime?
    var location: OcLocation?
    var active: Bool?
    var pending: String?
}

struct OcSessionsResponse: Decodable {
    var version: String?
    var sessions: [OcSession]
}

struct OcProject: Decodable, Identifiable {
    var id: String
    var name: String?
}

struct OcCursor: Decodable {
    var next: String?
}

struct OcToolContent: Decodable {
    var type: String?
    var text: String?
}

struct OcToolState: Decodable {
    var status: String?
    var content: [OcToolContent]?
}

struct OcContentPart: Decodable {
    var type: String
    var text: String?
    var name: String?
    var id: String?
    var state: OcToolState?
}

struct OcFile: Decodable {
    var name: String?
}

struct OcSkill: Decodable {
    var id: String?
    var name: String?
}

struct OcMessage: Decodable, Identifiable {
    var id: String
    var type: String
    var time: OcTime?
    var text: String?
    var content: [OcContentPart]?
    var files: [OcFile]?
    var skills: [OcSkill]?
}

struct OcMessagesResponse: Decodable {
    var data: [OcMessage]
    var cursor: OcCursor?
}

struct OcInboxPayload: Decodable {
    var text: String?
    var files: [OcFile]?
    var skills: [OcSkill]?
}

struct OcInboxItem: Decodable, Identifiable {
    var id: String
    var type: String
    var payload: OcInboxPayload?
    var delivery: String?
}

struct OcPermission: Decodable, Identifiable {
    var id: String
    var action: String?
    var resources: [String]?
    var message: String?
}

struct OcFormOption: Decodable {
    var value: String
    var label: String?
}

struct OcFormField: Decodable, Identifiable {
    var key: String
    var type: String
    var title: String?
    var required: Bool?
    var options: [OcFormOption]?

    var id: String { key }
}

struct OcForm: Decodable, Identifiable {
    var id: String
    var title: String?
    var fields: [OcFormField]
}

struct OcEvent: Decodable {
    var type: String
    var data: OcEventData?
}

struct OcEventData: Decodable {
    var sessionID: String?
    var ordinal: Int?
    var delta: String?
    var text: String?
}
