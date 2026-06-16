import SwiftUI

struct InterviewPrepTipsCard: View {
    let tip: InterviewPrepTip

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                Label("오늘의 준비 포인트", systemImage: "checklist")
                    .font(.subheadline.bold())

                Text(tip.title)
                    .font(.headline)

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(tip.items, id: \.self) { item in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 6))
                                .foregroundStyle(.secondary)
                                .padding(.top, 6)
                            Text(item)
                                .font(.subheadline)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }
}
