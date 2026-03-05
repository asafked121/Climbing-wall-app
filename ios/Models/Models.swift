import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let email: String
    let username: String
    let role: String
    let isBanned: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, email, username, role
        case isBanned = "is_banned"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.email = try container.decode(String.self, forKey: .email)
        self.username = try container.decode(String.self, forKey: .username)
        self.role = try container.decodeIfPresent(String.self, forKey: .role) ?? "student"
        self.isBanned = try container.decodeIfPresent(Bool.self, forKey: .isBanned) ?? false
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
    }
}

struct Setter: Codable, Identifiable {
    let id: Int
    let name: String
    let isActive: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case isActive = "is_active"
        case createdAt = "created_at"
    }
}

struct Zone: Codable, Identifiable {
    let id: Int
    let name: String
    let description: String?
    let routeType: String
    
    enum CodingKeys: String, CodingKey {
        case id, name, description
        case routeType = "route_type"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(Int.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.description = try container.decodeIfPresent(String.self, forKey: .description)
        self.routeType = try container.decodeIfPresent(String.self, forKey: .routeType) ?? "boulder"
    }
}

struct RouteColor: Codable, Identifiable, Hashable {
    let id: Int
    let name: String
    let hexValue: String
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case hexValue = "hex_value"
    }
}

struct Route: Codable, Identifiable {
    let id: Int
    let setterId: Int?
    let zoneId: Int
    let color: String
    let colorName: String?
    let intendedGrade: String
    let status: String
    let setDate: Date
    let photoUrl: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, color, status
        case colorName = "color_name"
        case setterId = "setter_id"
        case zoneId = "zone_id"
        case intendedGrade = "intended_grade"
        case setDate = "set_date"
        case photoUrl = "photo_url"
        case createdAt = "created_at"
    }
}

struct RouteDetail: Codable, Identifiable {
    let id: Int
    let setterId: Int?
    let zoneId: Int
    let color: String
    let colorName: String?
    let intendedGrade: String
    let status: String
    let setDate: Date
    let photoUrl: String?
    let createdAt: Date
    
    let zone: Zone?
    let setter: Setter?
    let gradeVotes: [GradeVote]
    let comments: [Comment]
    let routeRatings: [RouteRating]
    let ascents: [Ascent]?
    
    enum CodingKeys: String, CodingKey {
        case id, color, status, zone, setter, comments, ascents
        case colorName = "color_name"
        case setterId = "setter_id"
        case zoneId = "zone_id"
        case intendedGrade = "intended_grade"
        case setDate = "set_date"
        case photoUrl = "photo_url"
        case createdAt = "created_at"
        case gradeVotes = "grade_votes"
        case routeRatings = "route_ratings"
    }
}

struct GradeVote: Codable, Identifiable {
    let id: Int
    let userId: Int
    let routeId: Int
    let votedGrade: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case routeId = "route_id"
        case votedGrade = "voted_grade"
        case createdAt = "created_at"
    }
}

struct Comment: Codable, Identifiable {
    let id: Int
    let userId: Int
    let routeId: Int
    let content: String
    let createdAt: Date
    let user: User?
    
    enum CodingKeys: String, CodingKey {
        case id, content, user
        case userId = "user_id"
        case routeId = "route_id"
        case createdAt = "created_at"
    }
}

struct RouteRating: Codable, Identifiable {
    let id: Int
    let userId: Int
    let routeId: Int
    let rating: Int
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, rating
        case userId = "user_id"
        case routeId = "route_id"
        case createdAt = "created_at"
    }
}

struct Ascent: Codable, Identifiable {
    let id: Int
    let userId: Int
    let routeId: Int
    let ascentType: String
    let date: Date
    
    enum CodingKeys: String, CodingKey {
        case id, date
        case userId = "user_id"
        case routeId = "route_id"
        case ascentType = "ascent_type"
    }
}

// MARK: - Analytics

struct GradeCountItem: Codable, Identifiable {
    var id: String { grade }
    let grade: String
    let count: Int
}

struct RouteStatusCount: Codable {
    let active: Int
    let archived: Int
}

struct ZoneCountItem: Codable, Identifiable {
    var id: String { zone }
    let zone: String
    let count: Int
}

struct DayCountItem: Codable, Identifiable {
    var id: String { date }
    let date: String
    let count: Int
}

struct RatingCountItem: Codable, Identifiable {
    var id: Int { rating }
    let rating: Int
    let count: Int
}

struct TopRatedRouteItem: Codable, Identifiable {
    var id: Int { routeId }
    let routeId: Int
    let grade: String
    let color: String
    let avgRating: Double
    let ratingCount: Int

    enum CodingKeys: String, CodingKey {
        case grade, color
        case routeId = "route_id"
        case avgRating = "avg_rating"
        case ratingCount = "rating_count"
    }
}

struct AnalyticsResponse: Codable {
    let gradeDistribution: [GradeCountItem]
    let ascentsByGrade: [GradeCountItem]
    let routeStatus: RouteStatusCount
    let zoneUtilization: [ZoneCountItem]
    let activityTrend: [DayCountItem]
    let ratingDistribution: [RatingCountItem]
    let topRatedRoutes: [TopRatedRouteItem]

    enum CodingKeys: String, CodingKey {
        case gradeDistribution = "grade_distribution"
        case ascentsByGrade = "ascents_by_grade"
        case routeStatus = "route_status"
        case zoneUtilization = "zone_utilization"
        case activityTrend = "activity_trend"
        case ratingDistribution = "rating_distribution"
        case topRatedRoutes = "top_rated_routes"
    }
}

// MARK: - Custom Routes

struct CustomRoute: Codable, Identifiable {
    let id: Int
    let name: String
    let intendedGrade: String
    let photoUrl: String
    let author: BasicUser?
    
    enum CodingKeys: String, CodingKey {
        case id, name, author
        case intendedGrade = "intended_grade"
        case photoUrl = "photo_url"
    }
}

struct BasicUser: Codable {
    let username: String
}

struct CustomRouteDetailModel: Codable, Identifiable {
    let id: Int
    let name: String
    let intendedGrade: String
    let photoUrl: String
    let holds: String
    let author: BasicUser?
    let customGradeVotes: [CustomGradeVote]
    let customComments: [CustomComment]
    
    enum CodingKeys: String, CodingKey {
        case id, name, holds, author
        case intendedGrade = "intended_grade"
        case photoUrl = "photo_url"
        case customGradeVotes = "custom_grade_votes"
        case customComments = "custom_comments"
    }
}

struct CustomGradeVote: Codable, Identifiable {
    let id: Int
    let votedGrade: String
    
    enum CodingKeys: String, CodingKey {
        case id
        case votedGrade = "voted_grade"
    }
}

struct CustomComment: Codable, Identifiable {
    let id: Int
    let content: String
    let user: BasicUser?
}

