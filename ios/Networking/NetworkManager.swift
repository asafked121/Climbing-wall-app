import Foundation
import Combine

enum APIError: Error, LocalizedError {
    case badRequest(String)
    case serverError(Int)
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .badRequest(let message): return message
        case .serverError(let code): return "Server Error: \(code)"
        case .unknown: return "An unknown error occurred."
        }
    }
}

class NetworkManager {
    static let shared = NetworkManager()
    let baseURL = URL(string: "http://climb.local:8000")!
    private let session: URLSession
    
    private init() {
        let config = URLSessionConfiguration.default
        // Persist HTTPOnly cookies automatically for session management
        config.httpCookieStorage = HTTPCookieStorage.shared
        config.httpCookieAcceptPolicy = .always
        self.session = URLSession(configuration: config)
    }
    
    private func decodeDateFormatter() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let dateString = try container.decode(String.self)
            
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: dateString) { return date }
            
            formatter.formatOptions = [.withInternetDateTime]
            if let date = formatter.date(from: dateString) { return date }
            
            let fallback = DateFormatter()
            fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
            if let date = fallback.date(from: dateString) { return date }
            
            fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
            if let date = fallback.date(from: dateString) { return date }
            
            fallback.dateFormat = "yyyy-MM-dd"
            if let date = fallback.date(from: dateString) { return date }
            
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode date: \(dateString)")
        }
        return decoder
    }
    
    func register(email: String, username: String? = nil, password: String, role: String = "student", dateOfBirth: String? = nil) async throws {
        let url = baseURL.appendingPathComponent("auth/register")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body = ["email": email, "password": password, "role": role]
        if let username = username, !username.isEmpty {
            body["username"] = username
        }
        if let dateOfBirth = dateOfBirth {
            body["date_of_birth"] = dateOfBirth
        }
        
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.unknown
        }
        
        if httpResponse.statusCode != 201 {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorJson["detail"] as? String {
                throw APIError.badRequest(detail)
            }
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        // The backend /auth/register does not set the access_token cookie.
        // We must automatically log in the user after a successful registration.
        try await login(email: email, password: password)
    }
    
    func login(email: String, password: String) async throws {
        let url = baseURL.appendingPathComponent("auth/login")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["email": email, "password": password]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (_, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            // It might be 401 unauthorized
            throw URLError(.userAuthenticationRequired)
        }
    }
    
    func logout() {
        if let cookies = HTTPCookieStorage.shared.cookies(for: baseURL) {
            for cookie in cookies {
                HTTPCookieStorage.shared.deleteCookie(cookie)
            }
        }
    }
    
    func fetchCurrentUser() async throws -> User {
        let url = baseURL.appendingPathComponent("auth/me")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        // Let URLSession handle the cookies automatically
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 401 {
            throw URLError(.userAuthenticationRequired)
        } else if httpResponse.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        
        let decoder = decodeDateFormatter()
        return try decoder.decode(User.self, from: data)
    }
    
    func updateUsername(username: String) async throws -> User {
        let url = baseURL.appendingPathComponent("auth/me/username")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let updateData = ["username": username]
        request.httpBody = try JSONSerialization.data(withJSONObject: updateData)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 400 {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? String {
                throw NSError(domain: "AuthError", code: 400, userInfo: [NSLocalizedDescriptionKey: detail])
            }
            throw URLError(.badServerResponse)
        } else if httpResponse.statusCode == 401 {
            throw URLError(.userAuthenticationRequired)
        } else if httpResponse.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        
        let decoder = decodeDateFormatter()
        return try decoder.decode(User.self, from: data)
    }
    
    func fetchRoutes(zoneId: Int? = nil, grade: String? = nil, status: String? = "active", routeType: String? = nil) async throws -> [Route] {
        var components = URLComponents(url: baseURL.appendingPathComponent("routes"), resolvingAgainstBaseURL: true)!
        var queryItems = [URLQueryItem]()
        if let z = zoneId {
            queryItems.append(URLQueryItem(name: "zone_id", value: String(z)))
        }
        if let g = grade {
            queryItems.append(URLQueryItem(name: "intended_grade", value: g))
        }
        if let s = status, !s.isEmpty {
            queryItems.append(URLQueryItem(name: "status", value: s))
        }
        if let rt = routeType {
            queryItems.append(URLQueryItem(name: "route_type", value: rt))
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        
        let (data, response) = try await session.data(from: components.url!)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try decodeDateFormatter().decode([Route].self, from: data)
    }

    func fetchRouteDetails(routeId: Int) async throws -> RouteDetail {
        let url = baseURL.appendingPathComponent("routes/\(routeId)")
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            print(String(data: data, encoding: .utf8) ?? "")
            throw URLError(.badServerResponse)
        }
        
        return try decodeDateFormatter().decode(RouteDetail.self, from: data)
    }
    
    func submitVote(routeId: Int, grade: String) async throws -> GradeVote {
        let url = baseURL.appendingPathComponent("routes/\(routeId)/votes")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["voted_grade": grade]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            throw URLError(.badServerResponse)
        }
        
        return try decodeDateFormatter().decode(GradeVote.self, from: data)
    }
    
    func submitComment(routeId: Int, content: String) async throws -> Comment {
        let url = baseURL.appendingPathComponent("routes/\(routeId)/comments")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["content": content]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            throw URLError(.badServerResponse)
        }
        
        return try decodeDateFormatter().decode(Comment.self, from: data)
    }
    
    func submitRating(routeId: Int, rating: Int) async throws -> RouteRating {
        let url = baseURL.appendingPathComponent("routes/\(routeId)/ratings")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["rating": rating]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            throw URLError(.badServerResponse)
        }
        
        return try decodeDateFormatter().decode(RouteRating.self, from: data)
    }

    func submitAscent(routeId: Int, ascentType: String) async throws -> Ascent {
        let url = baseURL.appendingPathComponent("routes/\(routeId)/ascents")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["ascent_type": ascentType]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 201 else {
            throw URLError(.badServerResponse)
        }
        
        return try decodeDateFormatter().decode(Ascent.self, from: data)
    }
    
    func deleteAscent(ascentId: Int) async throws {
        let url = baseURL.appendingPathComponent("routes/ascents/\(ascentId)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        } else if httpResponse.statusCode != 204 {
            throw URLError(.badServerResponse)
        }
    }
    
    func fetchUserAscents(userId: Int) async throws -> [Ascent] {
        let url = baseURL.appendingPathComponent("routes/user/\(userId)/ascents")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try decodeDateFormatter().decode([Ascent].self, from: data)
    }
    
    // MARK: - Admin Endpoints
    
    func fetchZones() async throws -> [Zone] {
        let url = baseURL.appendingPathComponent("routes/zones")
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode([Zone].self, from: data)
    }
    
    func createZone(name: String, description: String?, routeType: String, allowsLead: Bool) async throws -> Zone {
        let url = baseURL.appendingPathComponent("admin/zones")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "name": name,
            "description": description ?? "",
            "route_type": routeType,
            "allows_lead": allowsLead
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        if httpResponse.statusCode != 201 {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? String {
                throw APIError.badRequest(detail)
            }
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(Zone.self, from: data)
    }
    
    func updateZone(zoneId: Int, name: String?, description: String?, routeType: String?, allowsLead: Bool?) async throws -> Zone {
        let url = baseURL.appendingPathComponent("admin/zones/\(zoneId)")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [:]
        if let name = name { body["name"] = name }
        if let description = description { body["description"] = description }
        if let routeType = routeType { body["route_type"] = routeType }
        if let allowsLead = allowsLead { body["allows_lead"] = allowsLead }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        if httpResponse.statusCode != 200 {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? String {
                throw APIError.badRequest(detail)
            }
            throw APIError.serverError(httpResponse.statusCode)
        }
        
        return try JSONDecoder().decode(Zone.self, from: data)
    }
    
    func deleteZone(zoneId: Int) async throws {
        let url = baseURL.appendingPathComponent("admin/zones/\(zoneId)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        if httpResponse.statusCode != 204 {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? String {
                throw APIError.badRequest(detail)
            }
            throw APIError.serverError(httpResponse.statusCode)
        }
    }
    
    func fetchColors() async throws -> [RouteColor] {
        let url = baseURL.appendingPathComponent("routes/colors")
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode([RouteColor].self, from: data)
    }

    func createColor(name: String, hexValue: String) async throws -> RouteColor {
        let url = baseURL.appendingPathComponent("admin/colors")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "name": name,
            "hex_value": hexValue
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        } else if httpResponse.statusCode != 201 {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? String {
                throw APIError.badRequest(detail)
            }
            throw URLError(.badServerResponse)
        }
        
        return try JSONDecoder().decode(RouteColor.self, from: data)
    }

    func deleteColor(colorId: Int) async throws {
        let url = baseURL.appendingPathComponent("admin/colors/\(colorId)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        } else if httpResponse.statusCode != 204 {
            throw URLError(.badServerResponse)
        }
    }
    
    func fetchSetters() async throws -> [Setter] {
        let url = baseURL.appendingPathComponent("admin/setters")
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        } else if httpResponse.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        
        return try decodeDateFormatter().decode([Setter].self, from: data)
    }

    func createSetter(name: String, isActive: Bool = true) async throws -> Setter {
        let url = baseURL.appendingPathComponent("admin/setters")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "name": name,
            "is_active": isActive
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        } else if httpResponse.statusCode != 201 {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? String {
                throw APIError.badRequest(detail)
            }
            throw URLError(.badServerResponse)
        }
        
        return try decodeDateFormatter().decode(Setter.self, from: data)
    }

    func updateSetterStatus(setterId: Int, isActive: Bool) async throws -> Setter {
        let url = baseURL.appendingPathComponent("admin/setters/\(setterId)")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = ["is_active": isActive]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        } else if httpResponse.statusCode != 200 {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? String {
                throw APIError.badRequest(detail)
            }
            throw URLError(.badServerResponse)
        }
        
        return try decodeDateFormatter().decode(Setter.self, from: data)
    }
    
    func createRoute(zoneId: Int, color: String, intendedGrade: String, setterId: Int? = nil, setDate: Date? = nil) async throws -> Route {
        let url = baseURL.appendingPathComponent("admin/routes")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "zone_id": zoneId,
            "color": color,
            "intended_grade": intendedGrade,
            "status": "active"
        ]
        if let setterId = setterId {
            body["setter_id"] = setterId
        }
        if let setDate = setDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            body["set_date"] = formatter.string(from: setDate)
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        } else if httpResponse.statusCode != 201 {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? String {
                throw APIError.badRequest(detail)
            }
            throw URLError(.badServerResponse)
        }
        
        return try decodeDateFormatter().decode(Route.self, from: data)
    }

    func uploadRoutePhoto(routeId: Int, imageData: Data, filename: String = "photo.jpg") async throws -> RouteDetail {
        let url = baseURL.appendingPathComponent("routes/\(routeId)/photo")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        } else if httpResponse.statusCode != 200 {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? String {
                throw APIError.badRequest(detail)
            }
            throw URLError(.badServerResponse)
        }
        
        return try decodeDateFormatter().decode(RouteDetail.self, from: data)
    }

    func updateRoute(routeId: Int, zoneId: Int?, color: String?, intendedGrade: String?, setterId: Int?, status: String?, setDate: Date? = nil) async throws -> Route {
        let url = baseURL.appendingPathComponent("admin/routes/\(routeId)")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [:]
        if let zoneId = zoneId { body["zone_id"] = zoneId }
        if let color = color { body["color"] = color }
        if let intendedGrade = intendedGrade { body["intended_grade"] = intendedGrade }
        if let setterId = setterId { body["setter_id"] = setterId }
        if let status = status { body["status"] = status }
        if let setDate = setDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            body["set_date"] = formatter.string(from: setDate)
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        } else if httpResponse.statusCode != 200 {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? String {
                throw APIError.badRequest(detail)
            }
            throw URLError(.badServerResponse)
        }
        
        return try decodeDateFormatter().decode(Route.self, from: data)
    }
    
    func archiveRoute(routeId: Int, isArchived: Bool) async throws -> Route {
        let url = baseURL.appendingPathComponent("admin/routes/\(routeId)/archive")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let status = isArchived ? "archived" : "active"
        let body = ["status": status]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        } else if httpResponse.statusCode != 200 {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? String {
                throw APIError.badRequest(detail)
            }
            throw URLError(.badServerResponse)
        }
        
        return try decodeDateFormatter().decode(Route.self, from: data)
    }

    // MARK: - Bulk Upload

    func downloadBulkTemplate() async throws -> URL {
        let url = baseURL.appendingPathComponent("admin/routes/bulk-template")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (tempURL, response) = try await session.download(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        
        // Move file to a permanent location
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let destinationURL = documentsDirectory.appendingPathComponent("route_import_template.xlsx")
        
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        return destinationURL
    }

    func uploadBulkRoutesFile(fileURL: URL) async throws -> BulkUploadResponse {
        let url = baseURL.appendingPathComponent("admin/routes/bulk-upload")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(fileURL.lastPathComponent)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/vnd.openxmlformats-officedocument.spreadsheetml.sheet\r\n\r\n".data(using: .utf8)!)
        
        let fileData = try Data(contentsOf: fileURL)
        body.append(fileData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 400 {
            // Check if this is a structured error response from validation
            if let decoded = try? decodeDateFormatter().decode(BulkUploadResponse.self, from: data) {
                return decoded
            }
            throw URLError(.badServerResponse)
        } else if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        } else if httpResponse.statusCode != 200 {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? String {
                throw APIError.badRequest(detail)
            }
            throw URLError(.badServerResponse)
        }
        
        return try decodeDateFormatter().decode(BulkUploadResponse.self, from: data)
    }

    func fetchUsers(role: String? = nil) async throws -> [User] {
        var components = URLComponents(url: baseURL.appendingPathComponent("admin/users"), resolvingAgainstBaseURL: true)!
        if let r = role {
            components.queryItems = [URLQueryItem(name: "role", value: r)]
        }
        
        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        } else if httpResponse.statusCode != 200 {
            throw URLError(.badServerResponse)
        }
        
        return try decodeDateFormatter().decode([User].self, from: data)
    }

    func updateUserRole(userId: Int, role: String) async throws -> User {
        let url = baseURL.appendingPathComponent("admin/users/\(userId)/role")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["role": role]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        } else if httpResponse.statusCode != 200 {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? String {
                throw APIError.badRequest(detail)
            }
            throw URLError(.badServerResponse)
        }
        
        return try decodeDateFormatter().decode(User.self, from: data)
    }

    func updateUserBanStatus(userId: Int, isBanned: Bool) async throws -> User {
        let url = baseURL.appendingPathComponent("admin/users/\(userId)/ban")
        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["is_banned": isBanned]
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        } else if httpResponse.statusCode != 200 {
            if let errorData = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let detail = errorData["detail"] as? String {
                throw APIError.badRequest(detail)
            }
            throw URLError(.badServerResponse)
        }
        
        return try decodeDateFormatter().decode(User.self, from: data)
    }

    func deleteComment(commentId: Int) async throws {
        let url = baseURL.appendingPathComponent("admin/comments/\(commentId)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        } else if httpResponse.statusCode != 204 {
            throw URLError(.badServerResponse)
        }
    }

    func deleteUser(userId: Int) async throws {
        let url = baseURL.appendingPathComponent("admin/users/\(userId)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        } else if httpResponse.statusCode != 204 {
            throw URLError(.badServerResponse)
        }
    }

    func deleteSetter(setterId: Int) async throws {
        let url = baseURL.appendingPathComponent("admin/setters/\(setterId)")
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        
        let (_, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
        
        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        } else if httpResponse.statusCode != 204 {
            throw URLError(.badServerResponse)
        }
    }

    // MARK: - Analytics

    func fetchAnalytics(status: String? = nil, routeType: String? = nil,
                        dateFrom: Date? = nil, dateTo: Date? = nil) async throws -> AnalyticsResponse {
        var components = URLComponents(url: baseURL.appendingPathComponent("admin/analytics"), resolvingAgainstBaseURL: true)!
        var queryItems = [URLQueryItem]()
        if let s = status { queryItems.append(URLQueryItem(name: "status", value: s)) }
        if let rt = routeType { queryItems.append(URLQueryItem(name: "route_type", value: rt)) }
        let dateFmt = DateFormatter()
        dateFmt.dateFormat = "yyyy-MM-dd"
        if let df = dateFrom { queryItems.append(URLQueryItem(name: "date_from", value: dateFmt.string(from: df))) }
        if let dt = dateTo { queryItems.append(URLQueryItem(name: "date_to", value: dateFmt.string(from: dt))) }
        if !queryItems.isEmpty { components.queryItems = queryItems }

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw URLError(.userAuthenticationRequired)
        } else if httpResponse.statusCode != 200 {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(AnalyticsResponse.self, from: data)
    }
}
