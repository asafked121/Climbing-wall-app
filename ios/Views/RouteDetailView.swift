import SwiftUI

struct RouteDetailView: View {
    let routeId: Int
    @StateObject private var viewModel: RouteDetailViewModel
    
    @State private var selectedGrade = "V0"
    
    @EnvironmentObject var loginViewModel: LoginViewModel
    @State private var selectedRating = 5
    @State private var showingEditRoute = false
    
    var isAdmin: Bool {
        let role = loginViewModel.currentUser?.role
        return role == "admin" || role == "super_admin"
    }
    
    var canManageRoutes: Bool {
        let role = loginViewModel.currentUser?.role
        return role == "admin" || role == "super_admin" || role == "setter"
    }
    
    private func hasLoggedAscent(type: String) -> Bool {
        guard let userId = loginViewModel.currentUser?.id,
              let ascents = viewModel.routeDetail?.ascents else { return false }
        return ascents.contains(where: { $0.userId == userId && $0.ascentType == type })
    }
    
    private var currentUserVote: GradeVote? {
        guard let userId = loginViewModel.currentUser?.id,
              let votes = viewModel.routeDetail?.gradeVotes else { return nil }
        return votes.first(where: { $0.userId == userId })
    }
    
    init(routeId: Int) {
        self.routeId = routeId
        _viewModel = StateObject(wrappedValue: RouteDetailViewModel(routeId: routeId))
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Group {
                    if viewModel.isLoading && viewModel.routeDetail == nil {
                        ProgressView("Loading details...")
                    } else if let error = viewModel.errorMessage {
                        Text(error).foregroundColor(.red)
                    } else if let detail = viewModel.routeDetail {
                        routeHeaderSection(detail)
                        Divider()
                        interactionSections(detail)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Route Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
            .task {
                await viewModel.fetchDetails()
                if let routeType = viewModel.routeDetail?.zone?.routeType {
                    selectedGrade = GradeHelper.defaultGrade(for: routeType)
                }
            }
        }
    }
    
    // MARK: - Header Section
    
    @ViewBuilder
    private func routeHeaderSection(_ detail: RouteDetail) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("\((detail.colorName ?? detail.color).capitalized) Route")
                .font(.largeTitle)
                .bold()
            Text("Setter: \(detail.setter?.name ?? "Unknown")")
                .foregroundColor(.secondary)
            Text("Set on: \(detail.setDate, style: .date)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            routePhoto(detail)
            
            Divider()
            
            Text("Intended Grade: \(detail.intendedGrade)")
                .font(.headline)
            
            consensusDisclosure
            
            Text("Average Rating: \(viewModel.averageRating) (\(detail.routeRatings.count) ratings)")
                .font(.subheadline)
                .foregroundColor(.yellow)
            
            ascentCountText(detail)
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private func routePhoto(_ detail: RouteDetail) -> some View {
        if let photoString = detail.photoUrl, let url = URL(string: "http://127.0.0.1:8000\(photoString)") {
            AsyncImage(url: url) { phase in
                if let image = phase.image {
                    image
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 300)
                        .cornerRadius(8)
                        .padding(.vertical, 8)
                } else if phase.error != nil {
                    Text("Image failed to load")
                        .font(.caption)
                        .foregroundColor(.red)
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
            }
        }
    }
    
    private var consensusDisclosure: some View {
        DisclosureGroup {
            if viewModel.gradeDistribution.isEmpty {
                Text("No votes yet.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                ConsensusBarChartView(distribution: viewModel.gradeDistribution)
                    .padding(.vertical, 8)
            }
        } label: {
            Text("Community Consensus: \(viewModel.averageGrade)")
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
    
    @ViewBuilder
    private func ascentCountText(_ detail: RouteDetail) -> some View {
        if detail.zone?.routeType == "boulder" {
            let boulderCount = detail.ascents?.filter({ $0.ascentType == "boulder" }).count ?? 0
            Text("Total Ascents: \(boulderCount)")
                .font(.subheadline)
                .foregroundColor(.secondary)
        } else {
            let topRopeCount = detail.ascents?.filter({ $0.ascentType == "top_rope" }).count ?? 0
            if [4, 7, 9].contains(detail.zone?.id ?? 0) {
                let leadCount = detail.ascents?.filter({ $0.ascentType == "lead" }).count ?? 0
                Text("Ascents: \(topRopeCount) Top Rope / \(leadCount) Lead")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            } else {
                Text("Ascents: \(topRopeCount) Top Rope")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Interaction Sections
    
    @ViewBuilder
    private func interactionSections(_ detail: RouteDetail) -> some View {
        VStack(alignment: .leading) {
            gradeVoteSection
            Divider()
            ascentSection(detail)
            Divider()
            ratingSection
            Divider()
            commentsSection(detail)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Grade Vote
    
    private var gradeVoteSection: some View {
        VStack(alignment: .leading) {
            Text("Log a Consensus Grade")
                .font(.headline)
            
            if loginViewModel.isGuest {
                Text("Log in to vote on this route's grade.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                if let vote = currentUserVote {
                    Text("You voted: **\(vote.votedGrade)**")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom, 2)
                }
                
                HStack {
                    Picker("Grade", selection: $selectedGrade) {
                        ForEach(viewModel.availableVoteGrades, id: \.self) { grade in
                            Text(grade).tag(grade)
                        }
                    }
                    .labelsHidden()
                    
                    Button(action: {
                        Task { await viewModel.submitVote(grade: selectedGrade) }
                    }) {
                        if viewModel.submittingVote {
                            ProgressView()
                        } else {
                            Text(currentUserVote != nil ? "Change Vote" : "Submit Vote")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.submittingVote)
                }
            }
        }
    }
    
    // MARK: - Ascent Logging
    
    @ViewBuilder
    private func ascentSection(_ detail: RouteDetail) -> some View {
        VStack(alignment: .leading) {
            Text("Log Ascent")
                .font(.headline)
            
            if loginViewModel.isGuest {
                Text("Log in to log your ascents on this route.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                if detail.zone?.routeType == "boulder" {
                    boulderAscentButtons
                } else {
                    ropeAscentButtons(detail)
                }
            }
        }
        .padding(.horizontal)
    }
    
    @ViewBuilder
    private var boulderAscentButtons: some View {
        if hasLoggedAscent(type: "boulder") {
            Button(action: {
                Task { await viewModel.unlogAscent(ascentType: "boulder", userId: loginViewModel.currentUser!.id) }
            }) {
                Text("Unlog Boulder")
            }
            .buttonStyle(.borderedProminent)
            .tint(.secondary)
            .disabled(viewModel.submittingAscent)
        } else {
            Button(action: {
                Task { await viewModel.submitAscent(ascentType: "boulder") }
            }) {
                Text("Log Boulder")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.submittingAscent)
        }
    }
    
    @ViewBuilder
    private func ropeAscentButtons(_ detail: RouteDetail) -> some View {
        HStack {
            if hasLoggedAscent(type: "top_rope") {
                Button(action: {
                    Task { await viewModel.unlogAscent(ascentType: "top_rope", userId: loginViewModel.currentUser!.id) }
                }) {
                    Text("Unlog Top Rope")
                }
                .buttonStyle(.borderedProminent)
                .tint(.secondary)
                .disabled(viewModel.submittingAscent)
            } else {
                Button(action: {
                    Task { await viewModel.submitAscent(ascentType: "top_rope") }
                }) {
                    Text("Log Top Rope")
                }
                .buttonStyle(.borderedProminent)
                .disabled(viewModel.submittingAscent)
            }
            
            if [4, 7, 9].contains(detail.zone?.id ?? 0) {
                leadButtons
            }
        }
    }
    
    @ViewBuilder
    private var leadButtons: some View {
        if hasLoggedAscent(type: "lead") {
            Button(action: {
                Task { await viewModel.unlogAscent(ascentType: "lead", userId: loginViewModel.currentUser!.id) }
            }) {
                Text("Unlog Lead")
            }
            .buttonStyle(.borderedProminent)
            .tint(.secondary)
            .disabled(viewModel.submittingAscent)
        } else {
            Button(action: {
                Task { await viewModel.submitAscent(ascentType: "lead") }
            }) {
                Text("Log Lead")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.submittingAscent)
        }
    }
    
    // MARK: - Rating
    
    private var ratingSection: some View {
        VStack(alignment: .leading) {
            Text("Rate This Route")
                .font(.headline)
            
            if loginViewModel.isGuest {
                Text("Log in to rate this route.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                HStack {
                    Picker("Rating", selection: $selectedRating) {
                        ForEach(1...5, id: \.self) { star in
                            Text("\(star) Stars").tag(star)
                        }
                    }
                    .labelsHidden()
                    
                    Button(action: {
                        Task { await viewModel.submitRating(rating: selectedRating) }
                    }) {
                        if viewModel.submittingRating {
                            ProgressView()
                        } else {
                            Text("Submit Rating")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.submittingRating)
                }
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Comments
    
    @ViewBuilder
    private func commentsSection(_ detail: RouteDetail) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Beta & Comments")
                .font(.headline)
            
            if loginViewModel.isGuest {
                Text("Log in to join the conversation and leave a comment.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
            } else {
                HStack {
                    TextField("Add a comment...", text: $viewModel.newCommentText)
                        .textFieldStyle(.roundedBorder)
                    
                    Button("Post") {
                        Task { await viewModel.submitComment() }
                    }
                    .disabled(viewModel.newCommentText.isEmpty || viewModel.submittingComment)
                }
            }
            
            ForEach(detail.comments) { comment in
                commentRow(comment)
            }
        }
        .padding(.horizontal)
    }
    
    private func commentRow(_ comment: Comment) -> some View {
        HStack {
            VStack(alignment: .leading) {
                Text(comment.user?.username ?? "User #\(comment.userId)")
                    .font(.caption)
                    .bold()
                Text(comment.content)
                    .font(.body)
                Text(comment.createdAt, style: .date)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            if isAdmin {
                Button(role: .destructive, action: {
                    Task { await viewModel.deleteComment(commentId: comment.id) }
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Toolbar
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if canManageRoutes {
            ToolbarItem(placement: .navigationBarTrailing) {
                if let detail = viewModel.routeDetail {
                    Menu {
                        Button("Edit Route") {
                            showingEditRoute = true
                        }
                        Button(detail.status == "archived" ? "Unarchive Route" : "Archive Route", role: .destructive) {
                            Task { await viewModel.toggleArchived() }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .sheet(isPresented: $showingEditRoute) {
                        EditRouteView(
                            routeId: routeId,
                            currentZoneId: detail.zone?.id,
                            currentColor: detail.color,
                            currentGrade: detail.intendedGrade,
                            currentSetterId: detail.setter?.id,
                            currentStatus: detail.status,
                            currentSetDate: detail.setDate,
                            onRouteEdited: {
                                Task { await viewModel.fetchDetails() }
                            }
                        )
                        .environmentObject(loginViewModel)
                    }
                }
            }
        }
    }
}
