import SwiftUI
import Charts

struct AnalyticsView: View {
    @StateObject private var viewModel = AnalyticsViewModel()
    @State private var showDateFrom = false
    @State private var showDateTo = false

    private let statusOptions = [("", "All"), ("active", "Active"), ("archived", "Archived")]
    private let typeOptions = [("", "All"), ("boulder", "Boulder"), ("top_rope", "Top Rope"), ("lead", "Lead")]

    var body: some View {
        Group {
            if let data = viewModel.analytics {
                analyticsContent(data)
            } else if let error = viewModel.errorMessage {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Error Loading Analytics")
                        .font(.headline)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Loading analytics…")
                        .foregroundColor(.secondary)
                }
            }
        }
        .navigationTitle("Wall Analytics")
        .task {
            await viewModel.loadAnalytics()
        }
    }

    // MARK: - Main Content

    @ViewBuilder
    private func analyticsContent(_ data: AnalyticsResponse) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                filterBar
                summaryCards(data)
                activityTrendChart(data)
                gradeDistributionChart(data)
                ascentsByGradeChart(data)
                zoneUtilizationChart(data)
                ratingDistributionChart(data)
                topRatedRoutesSection(data)
            }
            .padding()
        }
    }

    // MARK: - Filter Bar

    @ViewBuilder
    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status picker
            VStack(alignment: .leading, spacing: 4) {
                Text("STATUS")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                Picker("Status", selection: $viewModel.statusFilter) {
                    ForEach(statusOptions, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Route type picker
            VStack(alignment: .leading, spacing: 4) {
                Text("TYPE")
                    .font(.caption2.bold())
                    .foregroundColor(.secondary)
                Picker("Type", selection: $viewModel.routeTypeFilter) {
                    ForEach(typeOptions, id: \.0) { value, label in
                        Text(label).tag(value)
                    }
                }
                .pickerStyle(.segmented)
            }

            // Date range
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("FROM")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                    if let dateFrom = viewModel.dateFrom {
                        Button {
                            showDateFrom.toggle()
                        } label: {
                            HStack {
                                Text(dateFrom, format: .dateTime.month().day().year())
                                    .font(.caption)
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.bordered)
                        .onTapGesture(count: 2) {
                            viewModel.dateFrom = nil
                        }
                    } else {
                        Button {
                            viewModel.dateFrom = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
                            showDateFrom = true
                        } label: {
                            Label("Select", systemImage: "calendar")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("TO")
                        .font(.caption2.bold())
                        .foregroundColor(.secondary)
                    if let dateTo = viewModel.dateTo {
                        Button {
                            showDateTo.toggle()
                        } label: {
                            HStack {
                                Text(dateTo, format: .dateTime.month().day().year())
                                    .font(.caption)
                                Image(systemName: "xmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .buttonStyle(.bordered)
                        .onTapGesture(count: 2) {
                            viewModel.dateTo = nil
                        }
                    } else {
                        Button {
                            viewModel.dateTo = Date()
                            showDateTo = true
                        } label: {
                            Label("Select", systemImage: "calendar")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                }

                Spacer()

                Button("Apply") {
                    Task {
                        await viewModel.loadAnalytics()
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }

            if showDateFrom, let binding = Binding($viewModel.dateFrom) {
                DatePicker("From date", selection: binding, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
            }

            if showDateTo, let binding = Binding($viewModel.dateTo) {
                DatePicker("To date", selection: binding, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .labelsHidden()
            }
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
        .onChange(of: viewModel.statusFilter) { _, _ in
            Task { await viewModel.loadAnalytics() }
        }
        .onChange(of: viewModel.routeTypeFilter) { _, _ in
            Task { await viewModel.loadAnalytics() }
        }
    }

    // MARK: - Summary Cards

    @ViewBuilder
    private func summaryCards(_ data: AnalyticsResponse) -> some View {
        let totalAscents = data.ascentsByGrade.reduce(0) { $0 + $1.count }
        let totalRatings = data.ratingDistribution.reduce(0) { $0 + $1.count }

        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            summaryCard(value: "\(data.routeStatus.active)", label: "Active Routes", color: .green)
            summaryCard(value: "\(data.routeStatus.archived)", label: "Archived", color: .gray)
            summaryCard(value: "\(totalAscents)", label: "Total Ascents", color: .blue)
            summaryCard(value: "\(totalRatings)", label: "Total Ratings", color: .orange)
        }
    }

    private func summaryCard(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title.bold())
                .foregroundStyle(color.gradient)
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }

    // MARK: - Activity Trend

    @ViewBuilder
    private func activityTrendChart(_ data: AnalyticsResponse) -> some View {
        chartCard(title: "Activity Trend (30 Days)", icon: "chart.line.uptrend.xyaxis") {
            Chart(data.activityTrend) { item in
                let date = dateFromString(item.date)
                AreaMark(
                    x: .value("Date", date),
                    y: .value("Ascents", item.count)
                )
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.3), Color.blue.opacity(0.05)],
                        startPoint: .top, endPoint: .bottom
                    )
                )
                .interpolationMethod(.catmullRom)

                LineMark(
                    x: .value("Date", date),
                    y: .value("Ascents", item.count)
                )
                .foregroundStyle(Color.blue)
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 2.5))
            }
            .chartXAxis {
                AxisMarks(values: .automatic(desiredCount: 5)) { value in
                    if let date = value.as(Date.self) {
                        AxisValueLabel {
                            Text(date, format: .dateTime.month().day())
                                .font(.caption2)
                        }
                    }
                }
            }
            .frame(height: 200)
        }
    }

    // MARK: - Grade Distribution

    @ViewBuilder
    private func gradeDistributionChart(_ data: AnalyticsResponse) -> some View {
        chartCard(title: "Grade Distribution", icon: "chart.bar.fill") {
            Chart(data.gradeDistribution) { item in
                BarMark(
                    x: .value("Count", item.count),
                    y: .value("Grade", item.grade)
                )
                .foregroundStyle(Color.blue.gradient)
                .cornerRadius(4)
            }
            .frame(height: max(CGFloat(data.gradeDistribution.count) * 30, 100))
        }
    }

    // MARK: - Ascents by Grade

    @ViewBuilder
    private func ascentsByGradeChart(_ data: AnalyticsResponse) -> some View {
        chartCard(title: "Ascents by Grade", icon: "figure.climbing") {
            Chart(data.ascentsByGrade) { item in
                BarMark(
                    x: .value("Grade", item.grade),
                    y: .value("Ascents", item.count)
                )
                .foregroundStyle(Color.purple.gradient)
                .cornerRadius(4)
            }
            .frame(height: 200)
        }
    }

    // MARK: - Zone Utilization

    @ViewBuilder
    private func zoneUtilizationChart(_ data: AnalyticsResponse) -> some View {
        chartCard(title: "Zone Utilization", icon: "map.fill") {
            Chart(data.zoneUtilization) { item in
                BarMark(
                    x: .value("Routes", item.count),
                    y: .value("Zone", item.zone)
                )
                .foregroundStyle(Color.teal.gradient)
                .cornerRadius(4)
            }
            .frame(height: max(CGFloat(data.zoneUtilization.count) * 40, 100))
        }
    }

    // MARK: - Rating Distribution

    @ViewBuilder
    private func ratingDistributionChart(_ data: AnalyticsResponse) -> some View {
        chartCard(title: "Rating Distribution", icon: "star.fill") {
            Chart(data.ratingDistribution) { item in
                BarMark(
                    x: .value("Rating", "\(item.rating) ★"),
                    y: .value("Count", item.count)
                )
                .foregroundStyle(starColor(item.rating).gradient)
                .cornerRadius(4)
            }
            .frame(height: 200)
        }
    }

    // MARK: - Top Rated Routes

    @ViewBuilder
    private func topRatedRoutesSection(_ data: AnalyticsResponse) -> some View {
        chartCard(title: "Top Rated Routes", icon: "trophy.fill") {
            if data.topRatedRoutes.isEmpty {
                Text("No rated routes yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(data.topRatedRoutes.enumerated()), id: \.element.id) { index, route in
                        HStack(spacing: 12) {
                            rankBadge(index)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(route.grade)
                                    .font(.headline)
                                Text(route.color)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 2) {
                                Text(String(format: "%.1f ★", route.avgRating))
                                    .font(.subheadline.bold())
                                    .foregroundColor(.orange)
                                Text("\(route.ratingCount) ratings")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 10)
                        if index < data.topRatedRoutes.count - 1 {
                            Divider()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func chartCard<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon)
                .font(.headline)
            content()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(16)
    }

    private func dateFromString(_ dateString: String) -> Date {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: dateString) ?? Date()
    }

    private func rankBadge(_ index: Int) -> some View {
        let (color, textColor): (Color, Color) = {
            switch index {
            case 0: return (.yellow, .black)
            case 1: return (.gray, .white)
            case 2: return (.brown, .white)
            default: return (Color(.systemGray4), .secondary)
            }
        }()

        return Text("\(index + 1)")
            .font(.caption.bold())
            .frame(width: 28, height: 28)
            .background(color.gradient)
            .foregroundColor(textColor)
            .clipShape(Circle())
    }

    private func starColor(_ rating: Int) -> Color {
        switch rating {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .mint
        case 5: return .green
        default: return .gray
        }
    }
}

struct AnalyticsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AnalyticsView()
        }
    }
}
