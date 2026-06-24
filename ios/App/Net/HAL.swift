// Copyright 2026 R. Heller
// SPDX-License-Identifier: Apache-2.0

import Foundation

// HAL+JSON helpers.
//
// OpenProject's API v3 is HAL: most resources contain a `_links` dictionary
// where each value is an object with `href` (and often `title`). Embedded
// resources live under `_embedded`. We only need to decode the slices we
// surface — we keep custom decoders narrow so spec drift doesn't break the app.

/// One HAL link — `{ href: "...", title: "..." }`. Both fields are
/// optional in the spec; we treat empty hrefs the same as missing.
public struct HALLink: Decodable, Equatable, Sendable {
    public let href: String?
    public let title: String?
    public init(href: String?, title: String?) { self.href = href; self.title = title }

    /// Trailing path component of `href`. Useful for pulling ids out of
    /// `/api/v3/users/42` etc. without parsing URL components.
    public var trailingID: Int? {
        guard let href, let last = href.split(separator: "/").last else { return nil }
        return Int(last)
    }
}

/// HAL collection wrapper. `total` / `pageSize` / `offset` are at the top
/// level; results live under `_embedded.elements`.
public struct HALCollection<T: Decodable & Sendable>: Decodable, Sendable {
    public let total: Int?
    public let pageSize: Int?
    public let offset: Int?
    public let _embedded: Embedded?
    public let _links: Links?

    public struct Embedded: Decodable, Sendable { public let elements: [T] }
    public struct Links: Decodable, Sendable {
        public let nextByOffset: HALLink?
        public let prevByOffset: HALLink?
    }

    public var elements: [T] { _embedded?.elements ?? [] }
}

// MARK: - Endpoint resources (only the fields we surface)

public struct OPProject: Decodable, Identifiable, Sendable {
    public let id: Int
    public let identifier: String?
    public let name: String?
    public let description: HALFormattedText?
    public init(id: Int, identifier: String?, name: String?, description: HALFormattedText?) {
        self.id = id; self.identifier = identifier; self.name = name; self.description = description
    }
}

public struct HALFormattedText: Decodable, Sendable {
    public let raw: String?
    public let format: String?
}

public struct OPWorkPackage: Decodable, Identifiable, Sendable {
    public let id: Int
    public let subject: String?
    public let description: HALFormattedText?
    public let lockVersion: Int?
    public let _links: Links?

    public struct Links: Decodable, Sendable {
        public let status: HALLink?
        public let type: HALLink?
        public let priority: HALLink?
        public let assignee: HALLink?
        public let project: HALLink?
        public let author: HALLink?
    }

    public var statusName: String? { _links?.status?.title }
    public var typeName: String? { _links?.type?.title }
    public var assigneeName: String? { _links?.assignee?.title }
    public var priorityName: String? { _links?.priority?.title }
    public var projectName: String? { _links?.project?.title }
    public var projectID: Int? { _links?.project?.trailingID }
    public var statusID: Int? { _links?.status?.trailingID }
}

public struct OPMe: Decodable, Sendable {
    public let id: Int
    public let name: String?
    public let email: String?
}
