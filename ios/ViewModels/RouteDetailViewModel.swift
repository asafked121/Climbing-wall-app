import Foundation
import Combine

@MainActor
class RouteDetailViewModel: ObservableObject {
    @Published var routeDetail: RouteDetail?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    @Published var newCommentText: String = ""
    @Published var submittingComment = false
    @Published var submittingVote = false
    @Published var submittingRating = false
    @Published var submittingAscent = false
    
    let routeId: Int
    
    init(routeId: Int) {
        self.routeId = routeId
    }
    
    func fetchDetails() async {
        isLoading = true
        errorMessage = nil
        do {
            routeDetail = try await NetworkManager.shared.fetchRouteDetails(routeId: routeId)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }
    
    func submitComment() async {
        guard !newCommentText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        submittingComment = true
        do {
            let _ = try await NetworkManager.shared.submitComment(routeId: routeId, content: newCommentText)
            newCommentText = ""
            // Refresh to get new comment
            await fetchDetails()
        } catch {
            errorMessage = "Failed to submit comment: \(error.localizedDescription)"
        }
        submittingComment = false
    }
    func deleteComment(commentId: Int) async {
        do {
            try await NetworkManager.shared.deleteComment(commentId: commentId)
            await fetchDetails()
        } catch {
            errorMessage = "Failed to delete comment: \(error.localizedDescription)"
        }
    }
    
    func submitVote(grade: String) async {
        submittingVote = true
        do {
            let _ = try await NetworkManager.shared.submitVote(routeId: routeId, grade: grade)
            // Refresh to see updated votes
            await fetchDetails()
        } catch {
            errorMessage = "Failed to submit vote: \(error.localizedDescription)"
        }
        submittingVote = false
    }
    
    var averageGrade: String {
        guard let votes = routeDetail?.gradeVotes, !votes.isEmpty else {
            return "No consensus yet"
        }
        
        let counts = votes.reduce(into: [String: Int]()) { result, vote in
            result[vote.votedGrade, default: 0] += 1
        }
        if let max = counts.max(by: { a, b in a.value < b.value }) {
            return max.key
        }
        return "Unknown"
    }
    
    var gradeDistribution: [(grade: String, count: Int, percentage: Double)] {
        guard let votes = routeDetail?.gradeVotes, !votes.isEmpty else {
            return []
        }
        let totalVotes = Double(votes.count)
        var counts = [String: Int]()
        for vote in votes {
            counts[vote.votedGrade, default: 0] += 1
        }
        
        let gradeOrder = availableVoteGrades
        
        return counts.map { (grade: $0.key, count: $0.value, percentage: Double($0.value) / totalVotes) }
            .sorted { a, b in
                let indexA = gradeOrder.firstIndex(of: a.grade) ?? 99
                let indexB = gradeOrder.firstIndex(of: b.grade) ?? 99
                return indexA < indexB
            }
    }
    
    /// Grade list appropriate for the route's zone type, used for voting and consensus display.
    var availableVoteGrades: [String] {
        let routeType = routeDetail?.zone?.routeType ?? "boulder"
        return GradeHelper.voteGrades(for: routeType)
    }
    
    func submitRating(rating: Int) async {
        submittingRating = true
        do {
            let _ = try await NetworkManager.shared.submitRating(routeId: routeId, rating: rating)
            await fetchDetails()
        } catch {
            errorMessage = "Failed to submit rating: \(error.localizedDescription)"
        }
        submittingRating = false
    }
    
    func submitAscent(ascentType: String) async {
        submittingAscent = true
        do {
            let _ = try await NetworkManager.shared.submitAscent(routeId: routeId, ascentType: ascentType)
            await fetchDetails()
        } catch {
            errorMessage = "Failed to submit ascent: \(error.localizedDescription)"
        }
        submittingAscent = false
    }
    
    func unlogAscent(ascentType: String, userId: Int) async {
        guard let ascents = routeDetail?.ascents,
              let ascentToUnlog = ascents.first(where: { $0.userId == userId && $0.ascentType == ascentType }) else {
            return
        }
        
        submittingAscent = true
        do {
            try await NetworkManager.shared.deleteAscent(ascentId: ascentToUnlog.id)
            await fetchDetails()
        } catch {
            errorMessage = "Failed to unlog ascent: \(error.localizedDescription)"
        }
        submittingAscent = false
    }
    
    var averageRating: String {
        guard let ratings = routeDetail?.routeRatings, !ratings.isEmpty else {
            return "No ratings yet"
        }
        let sum = ratings.reduce(0) { $0 + $1.rating }
        let avg = Double(sum) / Double(ratings.count)
        return String(format: "%.1f / 5.0", avg)
    }
    
    func toggleArchived() async {
        guard let detail = routeDetail else { return }
        let newStatus = detail.status == "archived" ? false : true
        
        do {
            let _ = try await NetworkManager.shared.archiveRoute(routeId: routeId, isArchived: newStatus)
            await fetchDetails()
        } catch {
            errorMessage = "Failed to update route status: \(error.localizedDescription)"
        }
    }
}
