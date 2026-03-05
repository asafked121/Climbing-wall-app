import SwiftUI

struct CustomRouteDetailView: View {
    let routeId: Int
    @StateObject private var viewModel: CustomRouteDetailViewModel
    
    @State private var commentText = ""
    @State private var selectedGrade = "V0"
    let grades = ["V0", "V1", "V2", "V3", "V4", "V5", "V6", "V7", "V8", "V9", "V10"]
    
    init(routeId: Int) {
        self.routeId = routeId
        _viewModel = StateObject(wrappedValue: CustomRouteDetailViewModel(routeId: routeId))
    }
    
    var body: some View {
        ScrollView {
            if viewModel.isLoading && viewModel.route == nil {
                ProgressView("Loading...")
                    .padding(.top, 50)
            } else if let error = viewModel.errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            } else if let route = viewModel.route {
                VStack(alignment: .leading, spacing: 20) {
                    // Header
                    HStack {
                        VStack(alignment: .leading) {
                            Text(route.name)
                                .font(.title)
                                .fontWeight(.bold)
                            Text("By \(route.author?.username ?? "Unknown")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        
                        let voteCounts = route.customGradeVotes.reduce(into: [String: Int]()) { result, vote in
                            result[vote.votedGrade, default: 0] += 1
                        }
                        let consensus = voteCounts.max(by: { $0.value < $1.value })?.key ?? route.intendedGrade
                        
                        Text(consensus)
                            .font(.title2)
                            .fontWeight(.bold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(10)
                    }
                    .padding(.horizontal)
                    
                    // Photo with canvas overlay
                    AsyncImage(url: URL(string: "\(Config.apiBaseURL)\(route.photoUrl)")) { phase in
                        switch phase {
                        case .empty:
                            ProgressView()
                                .frame(height: 300)
                                .frame(maxWidth: .infinity)
                        case .success(let image):
                            // In real iOS we'd fetch the UIImage directly to get its dimensions, then draw the holds overlay.
                            // For this MVP, we will just show the image if we can't get natural size easily in pure SwiftUI AsyncImage.
                            // Actually we CAN get native image size if we use a state uimage. We'll stick to a simple image for now to prevent bugs.
                            image
                                .resizable()
                                .scaledToFit()
                                .cornerRadius(12)
                        case .failure:
                            Text("Failed to load image")
                                .frame(height: 300)
                        @unknown default:
                            EmptyView()
                        }
                    }
                    .padding(.horizontal)
                    
                    // Voting
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Vote on Grade")
                            .font(.headline)
                        
                        HStack {
                            Picker("Grade", selection: $selectedGrade) {
                                ForEach(grades, id: \.self) { Text($0) }
                            }
                            .pickerStyle(MenuPickerStyle())
                            
                            Button("Submit Vote") {
                                viewModel.vote(grade: selectedGrade)
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                    .padding(.horizontal)
                    
                    // Comments
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Comments")
                            .font(.headline)
                        
                        ForEach(route.customComments) { comment in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(comment.user?.username ?? "Unknown")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                Text(comment.content)
                                    .font(.subheadline)
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                        }
                        
                        HStack {
                            TextField("Add a comment...", text: $commentText)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            Button("Post") {
                                viewModel.comment(content: commentText)
                                commentText = ""
                            }
                            .disabled(commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
        }
        .navigationTitle("Route Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.fetchRoute()
        }
    }
}
