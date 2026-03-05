import SwiftUI

struct ConsensusBarChartView: View {
    let distribution: [(grade: String, count: Int, percentage: Double)]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(distribution, id: \.grade) { item in
                HStack {
                    Text(item.grade)
                        .frame(width: 40, alignment: .leading)
                        .font(.caption)
                    
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 16)
                            
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.blue)
                                .frame(width: max(0, geometry.size.width * CGFloat(item.percentage)), height: 16)
                        }
                    }
                    .frame(height: 16)
                    
                    Text("\(item.count)")
                        .frame(width: 30, alignment: .trailing)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
