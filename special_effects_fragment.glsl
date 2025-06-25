#version 330

uniform vec2 uCameraPos;
uniform sampler2D uTexture;

uniform vec2 uGlowCenter1 = vec2(0.0, 0.0);
uniform vec2 uGlowCenter2 = vec2(0.0, 0.0);
uniform float uGlowRadius1 = 32.0;
uniform float uGlowRadius2 = 32.0;
uniform vec3 uGlowColor1 = vec3(0.0, 0.0, 1.0);
uniform vec3 uGlowColor2 = vec3(1.0, 0.5, 0.0);
uniform float uGlowIntensity1 = 0.85;
uniform float uGlowIntensity2 = 0.85;

const vec2 GAME_HALF_SIZE = vec2(426.5, 240.0);

uniform float uTime = 0.0;

uniform bool uEnableGlow = true;
uniform bool uEnableHeat = false;

in vec2 texcoords;
out vec4 outColor;

float hash(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return fract(sin(p.x + p.y) * 43758.5453);
}

void main() {
    vec2 pixelWorldPos;
    pixelWorldPos.x = (texcoords.x - 0.5) * (GAME_HALF_SIZE.x * 2.0) + uCameraPos.x;
    float screenY = (1.0 - texcoords.y) * (GAME_HALF_SIZE.y * 2.0) - GAME_HALF_SIZE.y;
    pixelWorldPos.y = screenY + uCameraPos.y;

    float dist1 = length(pixelWorldPos - uGlowCenter1);
    float dist2 = length(pixelWorldPos - uGlowCenter2);

    float noise1 = hash(pixelWorldPos * 0.25);
    float noise2 = hash((pixelWorldPos + 123.456) * 0.25);
    float noisyDist1 = dist1 + (noise1 - 0.5) * 3.0;
    float noisyDist2 = dist2 + (noise2 - 0.5) * 3.0;

    float glow1 = 0.0;
    float glow2 = 0.0;
    if (uEnableGlow) {
        glow1 = 1.0 - smoothstep(uGlowRadius1 * 0.85, uGlowRadius1, noisyDist1);
        glow2 = 1.0 - smoothstep(uGlowRadius2 * 0.85, uGlowRadius2, noisyDist2);
        glow1 = pow(glow1, 3.0);
        glow2 = pow(glow2, 3.0);
        glow1 *= uGlowIntensity1;
        glow2 *= uGlowIntensity2;
    }

    vec2 distortion = vec2(0.0);
    float distortionAmount = 0.003 * max(glow1, glow2);
    if (uEnableHeat && (glow1 > 0.01 || glow2 > 0.01)) {
        float wave = sin(pixelWorldPos.y * 0.18 + uTime * 2.0 + pixelWorldPos.x * 0.12) * 0.5
                 + sin(pixelWorldPos.x * 0.15 - uTime * 1.5) * 0.5;
        distortion = vec2(wave * distortionAmount, distortionAmount * 0.5 * sin(uTime + pixelWorldPos.y * 0.09));
    }
    vec4 base = texture(uTexture, texcoords + distortion);

    if (base.a <= 0.01) {
        outColor = base;
        return;
    }

    vec3 glowColor = uGlowColor1 * glow1 + uGlowColor2 * glow2;
    float totalGlow = clamp(glow1 + glow2, 0.0, 0.12);

    vec3 finalColor = mix(base.rgb, glowColor, totalGlow);
    float finalAlpha = base.a;

    outColor = vec4(finalColor, finalAlpha);
}
