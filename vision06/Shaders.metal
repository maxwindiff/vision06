#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

float random(float2 st, float t) {
  return fract(sin(st.x + t) * cos(st.y + t) * 100);
}

float gaussian(float x, float sigma) {
  return exp(-0.5 * pow(x / sigma, 2.0));
}

float brightness(half3 rgb) {
  return dot(rgb, half3(0.299, 0.587, 0.114));
}

float smoothclamp(half low, half high, half dropoff, half x) {
  return smoothstep(low - dropoff, low, x) * smoothstep(high + dropoff, high, x);
}

[[ stitchable ]] half4 glow(float2 pos, float2 size, float3 finger) {
  pos /= size;
  half planeDist = length(finger.xy - pos);

  half alpha = (0.1 + pow(gaussian(planeDist, 0.2), 3) * 0.9) *
    smoothclamp(0, 1, 0.3, finger.x) *
    smoothclamp(0, 1, 0.3, finger.y) *
    smoothclamp(0, 0.05, 0.05, finger.z);
  return half4(0.9 + 0.1*pos.x, 0.9 + 0.1*pos.y, 1, 1) * alpha;
}
