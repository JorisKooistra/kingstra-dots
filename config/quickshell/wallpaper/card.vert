#version 440
layout(location = 0) in vec4 qt_Vertex;
layout(location = 1) in vec2 qt_MultiTexCoord0;
layout(location = 0) out vec2 qt_TexCoord0;
// Keep the block identical to card.frag, including unused members.
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
void main() {
    vec4 position = qt_Vertex;
    if (curveParams.y > 0.0) {
        float screenX = curveParams.x + position.x;
        float normalized = (screenX - curveParams.y * 0.5) / (curveParams.y * 0.5);
        // One continuous surface, rather than moving rigid hexagons up/down
        // independently: shared edges receive exactly the same deformation.
        position.y -= normalized * normalized * curveParams.z;
    }
    gl_Position = qt_Matrix * position;
    qt_TexCoord0 = qt_MultiTexCoord0;
}
