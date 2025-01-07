import SwiftUI

struct ButtonView: View {
  let size: CGFloat
  @State private var currentDateTime: String = ""

  private var dateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
    return formatter
  }

  var body: some View {
    ZStack {
      Rectangle()
        .stroke(Color.white, lineWidth: 1)
        .background(Color.clear)
      VStack(spacing: 0) {
        HStack(spacing: 0) {
          Text("Hululu").font(.system(size: 10, design: .monospaced))
          Spacer()
          Text("Swift").font(.system(size: 10, design: .monospaced))
        }
        Spacer()
        HStack(spacing: 0) {
          Text(currentDateTime).font(.system(size: 7, design: .monospaced))
          Spacer()
        }
      }
      .padding(.init(top: 2, leading: 3, bottom: 2, trailing: 3))
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(width: size, height: size)
    .onAppear {
      currentDateTime = dateFormatter.string(from: Date())
      Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
        currentDateTime = dateFormatter.string(from: Date())
      }
    }
  }
}

#Preview {
  ButtonView(size: 100)
}
