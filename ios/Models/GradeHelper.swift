import Foundation

/// Centralized grade lists for different route types.
/// Provides the correct grading system based on a zone's `routeType`.
enum GradeHelper {
    
    static let boulderGrades = [
        "V0", "V1", "V2", "V3", "V4", "V5", "V6", "V7", "V8", "V9", "V10", "V11", "V12"
    ]
    
    static let topRopeGrades = [
        "5.5", "5.6", "5.7", "5.8", "5.9",
        "5.10a", "5.10b", "5.10c", "5.10d",
        "5.11a", "5.11b", "5.11c", "5.11d",
        "5.12a", "5.12b", "5.12c", "5.12d",
    ]
    
    /// Grade list used for consensus voting — boulder uses V10+ as the top bucket.
    static let boulderVoteGrades = [
        "V0", "V1", "V2", "V3", "V4", "V5", "V6", "V7", "V8", "V9", "V10+"
    ]
    
    static func grades(for routeType: String) -> [String] {
        routeType == "top_rope" ? topRopeGrades : boulderGrades
    }
    
    static func voteGrades(for routeType: String) -> [String] {
        routeType == "top_rope" ? topRopeGrades : boulderVoteGrades
    }
    
    static func defaultGrade(for routeType: String) -> String {
        routeType == "top_rope" ? "5.5" : "V0"
    }
}
