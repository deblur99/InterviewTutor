import Charts
import SwiftUI

struct ProgressChartView: View {
    let sessions: [SessionScorePoint]

    @State private var axisMode: ProgressChartAxisMode = .sessionIndex
    @State private var enabledSeries: Set<ScoreSeries> = Set(ScoreSeries.allCases)

    private var latestScore: Int? {
        sessions.last?.overallScore
    }

    private var bestGrade: LetterGrade? {
        ProgressChartDataBuilder.bestGrade(in: sessions)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            summaryRow
            seriesToggles
            chart
        }
        .padding()
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 12))
    }

    private var header: some View {
        HStack {
            Text("연습 추이")
                .font(.title3.bold())
            Spacer()
            Picker("X축", selection: $axisMode) {
                ForEach(ProgressChartAxisMode.allCases) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 160)
        }
    }

    private var summaryRow: some View {
        HStack(spacing: 20) {
            summaryItem(title: "총 연습", value: "\(sessions.count)회")
            if let latestScore {
                summaryItem(title: "최근 종합", value: "\(latestScore)점")
            }
            if let bestGrade {
                HStack(spacing: 6) {
                    Text("최고 등급")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    GradeBadgeView(grade: bestGrade)
                }
            }
            Spacer()
        }
    }

    private func summaryItem(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
    }

    private var seriesToggles: some View {
        HStack(spacing: 12) {
            ForEach(ScoreSeries.allCases) { series in
                Toggle(isOn: binding(for: series)) {
                    Label(series.rawValue, systemImage: "circle.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.caption)
                        .foregroundStyle(seriesColor(series))
                }
                .toggleStyle(.button)
            }
        }
    }

    private var chart: some View {
        Chart {
            ForEach(sessions) { point in
                ForEach(ScoreSeries.allCases.filter { enabledSeries.contains($0) }) { series in
                    LineMark(
                        x: .value("X", xValue(for: point)),
                        y: .value("점수", point.value(for: series))
                    )
                    .foregroundStyle(by: .value("항목", series.rawValue))
                    .interpolationMethod(.catmullRom)

                    PointMark(
                        x: .value("X", xValue(for: point)),
                        y: .value("점수", point.value(for: series))
                    )
                    .foregroundStyle(by: .value("항목", series.rawValue))
                }
            }
        }
        .chartForegroundStyleScale([
            ScoreSeries.overall.rawValue: Color.purple,
            ScoreSeries.speech.rawValue: Color.blue,
            ScoreSeries.content.rawValue: Color.green,
            ScoreSeries.posture.rawValue: Color.teal,
        ])
        .chartYScale(domain: 0...100)
        .chartYAxis {
            AxisMarks(values: [0, 25, 50, 75, 100])
        }
        .frame(height: 220)
    }

    private func xValue(for point: SessionScorePoint) -> String {
        switch axisMode {
        case .date:
            point.xLabelDate
        case .sessionIndex:
            "\(point.sessionIndex)회"
        }
    }

    private func binding(for series: ScoreSeries) -> Binding<Bool> {
        Binding(
            get: { enabledSeries.contains(series) },
            set: { isOn in
                if isOn {
                    enabledSeries.insert(series)
                } else if enabledSeries.count > 1 {
                    enabledSeries.remove(series)
                }
            }
        )
    }

    private func seriesColor(_ series: ScoreSeries) -> Color {
        switch series {
        case .overall: .purple
        case .speech: .blue
        case .content: .green
        case .posture: .teal
        }
    }
}
