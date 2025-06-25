#version 330
uniform sampler2D uTexture;
uniform vec2 uCameraPos;

uniform vec2 uEffectCenter1 = vec2(0.0, 0.0);
uniform vec2 uEffectCenter2 = vec2(0.0, 0.0);
uniform float uEffectRadius1 = 14.0;
uniform float uEffectRadius2 = 14.0;

const vec2 GAME_HALF_SIZE = vec2(426.5, 240.0);

const vec3 EDGE_COLOR1 = vec3(1.0, 1.0, 1.0);
const vec3 EDGE_COLOR2 = vec3(1.0, 1.0, 1.0);
const vec3 GLOW_COLOR1 = vec3(0.0, 0.0, 1.0);
const vec3 GLOW_COLOR2 = vec3(1.0, 0.5, 0.0);
const float GLOW_INTENSITY = 2.0;
const float GLOW_RADIUS = 3.0;


in vec2 texcoords;
out vec4 outColor;

void main() {
    vec2 pixelWorldPos;
    pixelWorldPos.x = (texcoords.x - 0.5) * (GAME_HALF_SIZE.x * 2.0) + uCameraPos.x;
    float screenY = (1.0 - texcoords.y) * (GAME_HALF_SIZE.y * 2.0) - GAME_HALF_SIZE.y;
    pixelWorldPos.y = screenY + uCameraPos.y;

    float distToCenter1 = length(pixelWorldPos - uEffectCenter1);
    float distToCenter2 = length(pixelWorldPos - uEffectCenter2);

    if (distToCenter1 > uEffectRadius1 && distToCenter2 > uEffectRadius2) {
        outColor = texture(uTexture, texcoords);
        return;
    }

    vec4 center = texture(uTexture, texcoords);
    float alphaCenter = center.a;

    float dx = 1.0 / textureSize(uTexture, 0).x;
    float dy = 1.0 / textureSize(uTexture, 0).y;

    float glowAlpha1 = 0.0;
    float glowAlpha2 = 0.0;
    bool isEdge1 = false;
    bool isEdge2 = false;

    if (alphaCenter > 0.01) {
        for (int j = -1; j <= 1; ++j) {
            for (int i = -1; i <= 1; ++i) {
                if (i == 0 && j == 0) continue;
                vec2 offset = texcoords + vec2(float(i) * dx, float(j) * dy);
                float neighborAlpha = texture(uTexture, offset).a;
                
                if (neighborAlpha < 0.01) {
                    isEdge1 = true;
                    isEdge2 = true;
                    break;
                }
            }
            if (isEdge1) break;
        }
    }

    if (!isEdge1 && alphaCenter < 0.01) {
        if (distToCenter1 <= uEffectRadius1) {
            float minDist1 = GLOW_RADIUS + 1.0;
            
            for (int j = -2; j <= 2; ++j) {
                for (int i = -2; i <= 2; ++i) {
                    vec2 offset = texcoords + vec2(float(i) * dx, float(j) * dy);
                    float alpha = texture(uTexture, offset).a;

                    if (alpha > 0.01) {
                        bool isEdgePixel = false;
                        for (int y = -1; y <= 1 && !isEdgePixel; ++y) {
                            for (int x = -1; x <= 1; ++x) {
                                if (x == 0 && y == 0) continue;
                                vec2 neighborOffset = offset + vec2(float(x) * dx, float(y) * dy);
                                float nAlpha = texture(uTexture, neighborOffset).a;
                                if (nAlpha < 0.01) {
                                    isEdgePixel = true;
                                    break;
                                }
                            }
                        }

                        if (isEdgePixel) {
                            float dist = length(vec2(float(i), float(j)));
                            if (dist < minDist1) {
                                minDist1 = dist;
                            }
                        }
                    }
                }
            }

            if (minDist1 <= GLOW_RADIUS) {
                float t = 1.0 - (minDist1 / GLOW_RADIUS);
                glowAlpha1 = GLOW_INTENSITY * t * t;
            }
        }

        if (distToCenter2 <= uEffectRadius2) {
            float minDist2 = GLOW_RADIUS + 1.0;
            for (int j = -2; j <= 2; ++j) {
                for (int i = -2; i <= 2; ++i) {
                    vec2 offset = texcoords + vec2(float(i) * dx, float(j) * dy);
                    float alpha = texture(uTexture, offset).a;
                    if (alpha > 0.01) {
                        bool isEdgePixel = false;
                        for (int y = -1; y <= 1 && !isEdgePixel; ++y) {
                            for (int x = -1; x <= 1; ++x) {
                                if (x == 0 && y == 0) continue;
                                vec2 neighborOffset = offset + vec2(float(x) * dx, float(y) * dy);
                                float nAlpha = texture(uTexture, neighborOffset).a;
                                if (nAlpha < 0.01) {
                                    isEdgePixel = true;
                                    break;
                                }
                            }
                        }

                        if (isEdgePixel) {
                            float dist = length(vec2(float(i), float(j)));
                            if (dist < minDist2) {
                                minDist2 = dist;
                            }
                        }
                    }
                }
            }

            if (minDist2 <= GLOW_RADIUS) {
                float t = 1.0 - (minDist2 / GLOW_RADIUS);
                glowAlpha2 = GLOW_INTENSITY * t * t;
            }
        }
    }

    bool inEffect1 = distToCenter1 <= uEffectRadius1;
    bool inEffect2 = distToCenter2 <= uEffectRadius2;
    
    if (inEffect1 && inEffect2) {
        if (distToCenter1 < distToCenter2) {
            inEffect2 = false;
        } else {
            inEffect1 = false;
        }
    }

    if (isEdge1 && inEffect1) {
        outColor = vec4(EDGE_COLOR1, alphaCenter);
    } else if (isEdge2 && inEffect2) {
        outColor = vec4(EDGE_COLOR2, alphaCenter);
    } else if (alphaCenter > 0.01) {
        outColor = center;
    } else if (glowAlpha1 > 0.0 && inEffect1) {
        outColor = vec4(GLOW_COLOR1, glowAlpha1);
    } else if (glowAlpha2 > 0.0 && inEffect2) {
        outColor = vec4(GLOW_COLOR2, glowAlpha2);
    } else {
        outColor = vec4(0.0);
    }
}
