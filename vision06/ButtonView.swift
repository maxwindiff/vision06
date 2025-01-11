import SwiftUI

struct ButtonView: View {
  let size: CGFloat
  var finger: SIMD3<Float> = .zero
  @State private var currentDateTime: String = ""

  private var dateFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SS"
    return formatter
  }

  var shader: Shader {
    var s = ShaderLibrary.glow(.float2(size, size), .float3(finger.x, finger.y, finger.z))
    s.dithersColor = true
    return s
  }

  var body: some View {
    ZStack {
      Rectangle()
        .stroke(Color.white, lineWidth: 1)
        .background(shader)
      VStack(spacing: 0) {
        HStack(spacing: 0) {
          Text("Hululu").font(.system(size: 10, design: .monospaced))
          Spacer()
          Text("Swift").font(.system(size: 10, design: .monospaced))
        }
        Spacer()
        HStack(spacing: 0) {
          Text(currentDateTime).font(.system(size: 6.9, design: .monospaced))
            .padding([.trailing], -10)
          Spacer()
        }
      }
      .padding(.init(top: 2, leading: 3, bottom: 2, trailing: 3))
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(width: size, height: size)
    .onAppear {
      currentDateTime = dateFormatter.string(from: Date())
      Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { _ in
        currentDateTime = dateFormatter.string(from: Date())
      }
    }
  }
}

#Preview {
  @Previewable @State var finger: SIMD3<Float> = [0.2, 0.7, 0.1]
  VStack {
    ButtonView(size: 100, finger: finger)
    Slider(value: $finger.x, in: -1...1)
    Slider(value: $finger.y, in: -1...1)
    Slider(value: $finger.z, in: -1...1)
  }.frame(width: 200, height: 200)
}
