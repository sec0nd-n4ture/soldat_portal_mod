#version 330

#define DEBUG_VISUALS 0

uniform sampler2D uTexture;

uniform vec2 uCameraPos;
uniform vec2 uSourceOrigin = vec2(9999.0, 9999.0);
uniform vec2 uTargetOrigin = vec2(9999.0, 9999.0);
uniform vec2 uPortalSize = vec2(45.0, 50.0);
uniform float uSourceRotation = 0.0;
uniform float uTargetRotation = 0.0;

const vec2 GAME_HALF_SIZE = vec2(426.5, 240.0);

in vec2 texcoords;
out vec4 outColor;

vec2 screenToWorld(vec2 uv, vec2 camPos) {
    float x = (uv.x - 0.5) * 2.0 * GAME_HALF_SIZE.x + camPos.x;
    float y = (1.0 - uv.y) * 2.0 * GAME_HALF_SIZE.y - GAME_HALF_SIZE.y + camPos.y;
    return vec2(x, y);
}

vec2 worldToScreen(vec2 world, vec2 camPos) {
    float x = ((world.x - camPos.x) / (GAME_HALF_SIZE.x * 2.0)) + 0.5;
    float y = 1.0 - (((world.y - camPos.y + GAME_HALF_SIZE.y) / (GAME_HALF_SIZE.y * 2.0)));
    return vec2(x, y);
}

vec2 rotatePoint(vec2 point, vec2 pivot, float angle) {
    vec2 translated = point - pivot;
    float cos_neg = cos(-angle);
    float sin_neg = sin(-angle);
    vec2 rotated = vec2(
        translated.x * cos_neg - translated.y * sin_neg,
        translated.x * sin_neg + translated.y * cos_neg
    );
    return rotated + pivot;
}

bool pointInRotatedRect(vec2 point, vec2 origin, vec2 size, float rotation) {
    if (rotation == 0.0) {
        return all(greaterThanEqual(point, origin)) &&
               all(lessThan(point, origin + size));
    } else {
        vec2 pivot = origin + size * 0.5;
        vec2 translated = point - pivot;
        float cos_neg = cos(-rotation);
        float sin_neg = sin(-rotation);
        vec2 rotated = vec2(
            translated.x * cos_neg - translated.y * sin_neg,
            translated.x * sin_neg + translated.y * cos_neg
        );
        vec2 local_point = rotated + pivot;

        return all(greaterThanEqual(local_point, origin)) &&
               all(lessThan(local_point, origin + size));
    }
}

void main() {
    vec2 fragWorld = screenToWorld(texcoords, uCameraPos);
    vec4 color;

    bool inTarget = pointInRotatedRect(fragWorld, uTargetOrigin, uPortalSize, uTargetRotation);
    bool inSource = pointInRotatedRect(fragWorld, uSourceOrigin, uPortalSize, uSourceRotation);

    #if DEBUG_VISUALS
    float border = 3.0;
    bool onTargetBorder = false;
    bool onSourceBorder = false;

    if (inTarget) {
        vec2 targetPivot = uTargetOrigin + uPortalSize * 0.5;
        vec2 offset = rotatePoint(fragWorld, targetPivot, -uTargetRotation) - uTargetOrigin;
        
        if (offset.x < border || offset.x > uPortalSize.x - border || 
            offset.y < border || offset.y > uPortalSize.y - border) {
            onTargetBorder = true;
        }
    }

    if (inSource) {
        float flippedSourceRotation = uSourceRotation + 3.14159;
        vec2 sourcePivot = uSourceOrigin + uPortalSize * 0.5;
        vec2 offset = rotatePoint(fragWorld, sourcePivot, -flippedSourceRotation) - uSourceOrigin;
        
        if (offset.x < border || offset.x > uPortalSize.x - border || 
            offset.y < border || offset.y > uPortalSize.y - border) {
            onSourceBorder = true;
        }
    }
    #endif

    #if DEBUG_VISUALS
    if (onSourceBorder) {
        outColor = vec4(0.0, 0.0, 1.0, 0.8);
        return;
    }

    if (onTargetBorder) {
        outColor = vec4(1.0, 0.5, 0.0, 0.8);
        return;
    }
    #endif

    bool actuallyInTarget = inTarget && !inSource;
    bool actuallyInSource = inSource && !inTarget;

    if (actuallyInTarget) {
        vec2 targetPivot = uTargetOrigin + uPortalSize * 0.5;
        vec2 offset = rotatePoint(fragWorld, targetPivot, -uTargetRotation) - uTargetOrigin;

        if (offset.y <= uPortalSize.y * 0.5) {
            float flippedSourceRotation = uSourceRotation + 3.14159;
            vec2 sourcePivot = uSourceOrigin + uPortalSize * 0.5;
            vec2 sourceWorld = rotatePoint(uSourceOrigin + offset, sourcePivot, flippedSourceRotation);
            vec2 sourceUV = worldToScreen(sourceWorld, uCameraPos);

            if (sourceUV.x >= 0.0 && sourceUV.x <= 1.0 && sourceUV.y >= 0.0 && sourceUV.y <= 1.0) {
                vec4 sourceColor = texture(uTexture, sourceUV);
                if (sourceColor.a > 0.1) {
                    color = sourceColor;
                } else {
                    color = texture(uTexture, texcoords);
                }
            } else {
                color = texture(uTexture, texcoords);
            }
        } else {
            color = texture(uTexture, texcoords);
        }
    } else if (actuallyInSource) {
        vec2 sourcePivot = uSourceOrigin + uPortalSize * 0.5;
        vec2 offset = rotatePoint(fragWorld, sourcePivot, -uSourceRotation) - uSourceOrigin;

        if (offset.y <= uPortalSize.y * 0.5) {
            float flippedTargetRotation = uTargetRotation + 3.14159;
            vec2 targetPivot = uTargetOrigin + uPortalSize * 0.5;
            vec2 targetWorld = rotatePoint(uTargetOrigin + offset, targetPivot, flippedTargetRotation);
            vec2 targetUV = worldToScreen(targetWorld, uCameraPos);

            if (targetUV.x >= 0.0 && targetUV.x <= 1.0 && targetUV.y >= 0.0 && targetUV.y <= 1.0) {
                vec4 targetColor = texture(uTexture, targetUV);
                if (targetColor.a > 0.1) {
                    color = targetColor;
                } else {
                    color = texture(uTexture, texcoords);
                }
            } else {
                color = texture(uTexture, texcoords);
            }
        } else {
            color = texture(uTexture, texcoords);
        }
    } else {
        color = texture(uTexture, texcoords);
    }

    #if DEBUG_VISUALS
    if (inSource) {
        color.rgb = mix(color.rgb, vec3(1.0, 0.0, 0.0), 0.3);
    }
    #endif

    if (color.a == 0.0) discard;

    outColor = color;
}
