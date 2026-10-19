#version 440
// Silhouette outline: for every pixel, look for icon alpha in a ring of
// neighbours around it. Pixels outside the icon but within `radius` px of it
// get the outline color; the icon itself is drawn on top, untouched.
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 color;
    vec2 texel;     // 1 / source texture size
    float radius;   // outline thickness in source pixels
};
layout(binding = 1) uniform sampler2D src;

void main() {
    float own = texture(src, qt_TexCoord0).a;
    float m = 0.0;
    for (int ring = 1; ring <= 3; ++ring) {
        float r = radius * float(ring) / 3.0;
        for (int i = 0; i < 16; ++i) {
            float a = 6.2831853 * float(i) / 16.0;
            m = max(m, texture(src, qt_TexCoord0 + vec2(cos(a), sin(a)) * texel * r).a);
        }
    }
    float outline = clamp(m - own, 0.0, 1.0);
    fragColor = vec4(color.rgb * outline, outline) * color.a * qt_Opacity;
}
