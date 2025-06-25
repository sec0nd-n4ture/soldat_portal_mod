#version 330
layout (location = 0) in vec2 in_position;
out vec2 texcoords;
void main() {
    texcoords = in_position;
    gl_Position = vec4(in_position * 2.0 - 1.0, 0.0, 1.0);
}