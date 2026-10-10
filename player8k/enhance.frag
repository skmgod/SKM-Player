#version 440
// GPU 화질 개선: 노이즈 제거(3x3 양방향) → 적응형 선명화(CAS 방식) → 대비/채도
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float sharp;        // 0 ~ 1
    float denoise;      // 0 ~ 1
    float contrast;     // 1 = 그대로
    float saturation;   // 1 = 그대로
    vec2 texel;         // 1 / 텍스처 크기
};
layout(binding = 1) uniform sampler2D src;

vec3 tap(vec2 o) { return texture(src, qt_TexCoord0 + o * texel).rgb; }

void main() {
    vec3 c  = tap(vec2( 0.0,  0.0));
    vec3 n  = tap(vec2( 0.0, -1.0));
    vec3 s  = tap(vec2( 0.0,  1.0));
    vec3 w  = tap(vec2(-1.0,  0.0));
    vec3 e  = tap(vec2( 1.0,  0.0));
    vec3 col = c;

    // 1) 노이즈 제거: 색이 비슷한 이웃만 섞는다 (경계는 보존)
    if (denoise > 0.001) {
        vec3 nw = tap(vec2(-1.0, -1.0));
        vec3 ne = tap(vec2( 1.0, -1.0));
        vec3 sw = tap(vec2(-1.0,  1.0));
        vec3 se = tap(vec2( 1.0,  1.0));
        float sig = mix(0.02, 0.14, denoise);
        float inv = 1.0 / (2.0 * sig * sig);
        vec3 acc = c;
        float wsum = 1.0;
        vec3 nb[8] = vec3[8](n, s, w, e, nw, ne, sw, se);
        for (int i = 0; i < 8; ++i) {
            vec3 d = nb[i] - c;
            float k = exp(-dot(d, d) * inv);
            acc += nb[i] * k;
            wsum += k;
        }
        col = mix(c, acc / wsum, clamp(denoise * 1.4, 0.0, 1.0));
    }

    // 2) 적응형 선명화 (AMD FidelityFX CAS 방식: 이미 대비가 큰 곳은 덜 건드림)
    if (sharp > 0.001) {
        vec3 mn = min(min(min(n, s), min(w, e)), c);
        vec3 mx = max(max(max(n, s), max(w, e)), c);
        vec3 amp = clamp(min(mn, 1.0 - mx) / max(mx, vec3(1e-4)), 0.0, 1.0);
        amp = sqrt(amp);
        float peak = -1.0 / mix(8.0, 4.0, sharp);
        vec3 wgt = amp * peak;
        vec3 res = (col + (n + s + w + e) * wgt) / (1.0 + 4.0 * wgt);
        col = mix(col, clamp(res, 0.0, 1.0), clamp(sharp * 1.3, 0.0, 1.0));
    }

    // 3) 대비 / 채도
    col = (col - 0.5) * contrast + 0.5;
    float luma = dot(col, vec3(0.2126, 0.7152, 0.0722));
    col = mix(vec3(luma), col, saturation);

    fragColor = vec4(clamp(col, 0.0, 1.0), 1.0) * qt_Opacity;
}
