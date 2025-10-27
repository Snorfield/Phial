#version 330 compatibility

#include "/assets/palette.glsl"

// #define Dithering
#define ditheringScale 2 // [1 2 3 4 5 6 7 8 9 10]
#define Vignette 
#define vignetteSize 0.2 // [0.1 0.2 0.3 0.4 0.5 0.6 0.7 0.8 0.9 1]
// #define vignetteQuantization 
#define Pixelization 
#define pixelizationSize 250.0 // [30.0 40.0 50.0 60.0 70.0 80.0 90.0 100.0 150.0 200.0 250.0 300.0 350.0 400.0 450.0 500.0 550.0 600.0 650.0 750.0 1000.0]
#define Quantization 

uniform sampler2D colortex0;

uniform float viewHeight;
uniform float viewWidth;

in vec2 texcoord;
layout(location = 0) out vec4 color;

float perceptualDistance(vec3 a, vec3 b) {
    vec3 diff = a - b;
    return sqrt(diff.r * diff.r * 0.2126 + diff.g * diff.g * 0.7152 + diff.b * diff.b * 0.0722);
}

void main() {

    vec2 resolution = vec2(viewWidth, viewHeight);
    ivec2 texSize = textureSize(colortex0, 0);       
    ivec2 fragCoord = ivec2(texcoord * vec2(texSize)); 
    vec2 uv = fragCoord/resolution;

    vec2 samplingCoords = uv;
    vec2 trueCoords = fragCoord;

    #ifdef Pixelization
        float factor = resolution.x / resolution.y;
        float pixels = pixelizationSize;
        
        float shiftedX = round(uv.x * pixels) / pixels;
        float shiftedY = round(uv.y * (pixels / factor)) / pixels * factor;

        samplingCoords = vec2(shiftedX, shiftedY);
        trueCoords = samplingCoords * resolution;
    #endif

    vec4 image = texture(colortex0, samplingCoords);

    vec4 outputColor = image;

    float vignetteFactor = 0.0;

    #ifdef Vignette
        vec2 shift = abs(samplingCoords - 0.5);
        float dist = distance(shift, vec2(0.0, 0.0));
        vignetteFactor = smoothstep(0.2, 0.9, dist) * vignetteSize;
        #ifdef vignetteQuantization
            image.rgb -= vignetteFactor;
        #endif
    #endif

    #ifdef Quantization
        int minimumIndex = 0;
        float minimumDistance = 10.0;
        
        int secondIndex = 0;
        
        for (int i = 0; i < colorNum; i++) {
            float colorDistance = perceptualDistance(image.rgb, colors[i]);
            if (colorDistance < minimumDistance) {
                secondIndex = minimumIndex;
                minimumIndex = i;
                minimumDistance = colorDistance;
            }
        }

        int index = minimumIndex;
        outputColor = vec4(colors[minimumIndex], 1.0);
    #endif

    #ifdef Dithering
        const mat4 bayer = mat4(
            0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0,
        12.0/16.0,  4.0/16.0, 14.0/16.0,  6.0/16.0,
            3.0/16.0, 11.0/16.0,  1.0/16.0,  9.0/16.0,
        15.0/16.0,  7.0/16.0, 13.0/16.0,  5.0/16.0
        );
        
        int positionX = (int(fragCoord.x) / ditheringScale) % 4;
        int positionY = (int(fragCoord.y) / ditheringScale) % 4;
        
        float threshold = bayer[positionY][positionX];
        
        float distanceFirst = perceptualDistance(image.rgb, colors[minimumIndex]);
        float distanceSecond = perceptualDistance(image.rgb, colors[secondIndex]);
        
        float fraction = distanceSecond / (distanceFirst + distanceSecond + 1e-6);
        
        if (fraction >= threshold) {
            index = secondIndex;
        }

        outputColor = vec4(colors[index], 1.0);
    #endif

    #if defined Vignette && !defined vignetteQuantization
        outputColor.rgb -= vignetteFactor;
    #endif

    #if defined vignetteQuantization && !defined Quantization && defined Vignette
        outputColor.rgb -= vignetteFactor;
    #endif

    color = vec4(outputColor);
}




