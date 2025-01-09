#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

float random(float2 st, float t) {
  return fract(sin(st.x + t) * cos(st.y + t) * 100);
}

float gaussian(float x, float sigma) {
  return exp(-0.5 * pow(x / sigma, 2.0)) / (sigma * sqrt(2.0 * M_PI_F));
}

float brightness(half3 rgb) {
  return dot(rgb, half3(0.299, 0.587, 0.114));
}

[[ stitchable ]] half4 glow(float2 pos, float3 finger) {
  return half4(0.1, 0.1, 0.1, 0.1);
}
