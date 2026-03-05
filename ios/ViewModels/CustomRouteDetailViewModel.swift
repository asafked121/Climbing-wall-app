import Foundation

class CustomRouteDetailViewModel: ObservableObject {
    @Published var route: CustomRouteDetailModel?
    @Published var holds: [CreateCustomRouteViewModel.Hold] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    let routeId: Int
    
    init(routeId: Int) {
        self.routeId = routeId
    }
    
    func fetchRoute() {
        guard let url = URL(string: "\(Config.apiBaseURL)/custom-routes/\(routeId)") else { return }
        
        isLoading = true
        errorMessage = nil
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        if let token = KeychainHelper.shared.read(service: "climbapp", account: "token") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    return
                }
                
                guard let data = data else {
                    self.errorMessage = "No data received"
                    return
                }
                
                do {
                    self.route = try JSONDecoder().decode(CustomRouteDetailModel.self, from: data)
                    if let holdsString = self.route?.holds, let holdsData = holdsString.data(using: .utf8) {
                        self.holds = try JSONDecoder().decode([CreateCustomRouteViewModel.Hold].self, from: holdsData)
                    }
                } catch {
                    self.errorMessage = "Failed to decode route detail"
                    print("Decode error:", error)
                }
            }
        }.resume()
    }
    
    func vote(grade: String) {
        guard let url = URL(string: "\(Config.apiBaseURL)/custom-routes/\(routeId)/vote") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = KeychainHelper.shared.read(service: "climbapp", account: "token") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = ["voted_grade": grade]
        request.httpBody = try? JSONEncoder().encode(body)
        
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                DispatchQueue.main.async {
                    self.fetchRoute()
                }
            }
        }.resume()
    }
    
    func comment(content: String) {
        guard let url = URL(string: "\(Config.apiBaseURL)/custom-routes/\(routeId)/comment") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        if let token = KeychainHelper.shared.read(service: "climbapp", account: "token") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let body = ["content": content]
        request.httpBody = try? JSONEncoder().encode(body)
        
        URLSession.shared.dataTask(with: request) { _, response, _ in
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                DispatchQueue.main.async {
                    self.fetchRoute()
                }
            }
        }.resume()
    }
}
