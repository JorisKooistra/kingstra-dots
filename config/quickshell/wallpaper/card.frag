#version 440
// Compile: /usr/lib/qt6/bin/qsb --glsl '100 es,120,150' -o card.frag.qsb card.frag
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 cardSize;
    vec2 cropScale;
    vec4 accent;
    float shapeKind;
    float borderWidth;
    float imageOpacity;
    vec4 curveParams;
};
layout(binding = 1) uniform sampler2D source;

void main() {
    vec2 size = max(cardSize, vec2(1.0));
    vec2 p = qt_TexCoord0 * size;
    vec2 center = abs(p - size * 0.5);
    float distance;
    if (shapeKind > 1.5) {
        // Flat-top hexagon; normalized edge distances give a uniform outline.
        float slope = size.x / (2.0 * size.y);
        distance = max(center.y - size.y * 0.5,
            (center.x + slope * center.y - size.x * 0.5) / sqrt(1.0 + slope * slope));
    } else if (shapeKind > 0.5) {
        float slant = min(30.0, size.x * 0.2);
        float slope = slant / size.y;
        distance = max(max(-p.y, p.y - size.y),
            max(slant - slope * p.y - p.x, p.x - size.x + slope * p.y) / sqrt(1.0 + slope * slope));
    } else {
        vec2 q = center - size * 0.5 + 16.0;
        distance = length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - 16.0;
    }
    vec2 uv = (qt_TexCoord0 - 0.5) * cropScale + 0.5;
    vec4 pixel = texture(source, uv) * imageOpacity;
    float border = borderWidth > 0.0 ? smoothstep(-borderWidth - 0.5, -borderWidth + 0.5, distance) : 0.0;
    pixel = mix(pixel, accent, border);
    float coverage = 1.0 - smoothstep(-1.0, 0.0, distance);
    fragColor = pixel * coverage * qt_Opacity;
}
