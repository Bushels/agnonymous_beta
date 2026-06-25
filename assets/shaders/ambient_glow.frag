#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;

out vec4 fragColor;

void main() {
    // Normalized coordinates (0 to 1)
    vec2 uv = FlutterFragCoord().xy / uSize.xy;
    
    // Slow animated positions for gradient centers
    float t = uTime * 0.15;
    
    // Center 1: Soft Forest Green (representing prairie growth)
    vec2 c1 = vec2(
        0.3 + 0.25 * sin(t * 0.8 + 1.0),
        0.4 + 0.25 * cos(t * 1.1 + 0.5)
    );
    float d1 = length(uv - c1);
    float glow1 = smoothstep(0.7, 0.0, d1);
    vec3 col1 = vec3(0.04, 0.16, 0.07) * glow1; // Deep warm forest green
    
    // Center 2: Warm Amber (representing harvest/sunlight)
    vec2 c2 = vec2(
        0.7 + 0.25 * cos(t * 0.9 + 2.0),
        0.6 + 0.25 * sin(t * 0.7 + 3.1)
    );
    float d2 = length(uv - c2);
    float glow2 = smoothstep(0.65, 0.0, d2);
    vec3 col2 = vec3(0.16, 0.11, 0.03) * glow2; // Muted glowing amber
    
    // Center 3: Earth Soil (representing fertile soil foundation)
    vec2 c3 = vec2(
        0.5 + 0.2 * sin(t * 1.3 - 1.0),
        0.3 + 0.2 * cos(t * 0.8 + 2.5)
    );
    float d3 = length(uv - c3);
    float glow3 = smoothstep(0.6, 0.0, d3);
    vec3 col3 = vec3(0.10, 0.06, 0.02) * glow3; // Rich deep soil brown
    
    // Ambient base (very dark agricultural night sky)
    vec3 baseColor = vec3(0.06, 0.07, 0.05);
    
    // Combine colors
    vec3 finalCol = baseColor + col1 + col2 + col3;
    
    // Add subtle cinematic noise/grain to reduce banding and feel texture-rich
    float grain = fract(sin(dot(FlutterFragCoord().xy, vec2(12.9898, 78.233))) * 43758.5453) * 0.012;
    finalCol += vec3(grain);
    
    fragColor = vec4(finalCol, 1.0);
}
