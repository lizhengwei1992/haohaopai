//
// GLSL fragment shader for a 2D water effect.
//
// Copyright (c) 2013 by Lasse Öörni
//
// This software is provided 'as-is', without any express or implied
// warranty. In no event will the authors be held liable for any damages
// arising from the use of this software.
//
// Permission is granted to anyone to use this software for any purpose,
// including commercial applications, and to alter it and redistribute it
// freely, subject to the following restrictions:
//
// 1. The origin of this software must not be misrepresented; you must not
//    claim that you wrote the original software. If you use this software
//    in a product, an acknowledgment in the product documentation would be
//    appreciated but is not required.
//
// 2. Altered source versions must be plainly marked as such, and must not be
//    misrepresented as being the original software.
//
// 3. This notice may not be removed or altered from any source
//    distribution.
//

#version 320 es
precision mediump float;

// Flutter uniforms
layout(location = 0) out vec4 fragColor;
layout(location = 0) uniform vec2 uResolution;
layout(location = 1) uniform float uTime;
layout(location = 2) uniform sampler2D uTexture;

// Vertex shader output
in vec2 v_texCoord;

// Parameters
const float speed = 0.3;
const float frequency = 8.0;
const float amplitude = 0.01;

void main()
{
    // Output a solid magenta color.
    // This is the simplest possible shader to test the asset pipeline.
    fragColor = vec4(1.0, 0.0, 1.0, 1.0);
} 