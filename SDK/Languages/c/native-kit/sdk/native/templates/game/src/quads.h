// A minimal GL quad batch: one shader, one dynamic buffer, coloured rectangles in pixel coordinates (origin top-left).
// It is a starting point for your own renderer: swap the shader for your own look (the kit's NexGFX, include/nexvyn/
// nexgfx_native.h, is the next step when you need meshes, textures and render targets).
#pragma once
#include <glad/glad.h>
#include <stddef.h>

struct QuadBatch {
    GLuint prog = 0, vao = 0, vbo = 0;
    GLint u_size = -1;
    static const int kMax = 4096;
    float verts[kMax * 6 * 6];  // x, y, r, g, b, a per vertex
    int count = 0;

    bool init() {
        const char* vs =
            "#version 330 core\n"
            "layout(location=0) in vec2 p; layout(location=1) in vec4 c; uniform vec2 size; out vec4 vc;\n"
            "void main(){ vc = c; gl_Position = vec4(p.x / size.x * 2.0 - 1.0, 1.0 - p.y / size.y * 2.0, 0.0, 1.0); }\n";
        const char* fs =
            "#version 330 core\n"
            "in vec4 vc; out vec4 o; void main(){ o = vc; }\n";
        GLuint v = compile(GL_VERTEX_SHADER, vs), f = compile(GL_FRAGMENT_SHADER, fs);
        if (!v || !f) return false;
        prog = glCreateProgram();
        glAttachShader(prog, v);
        glAttachShader(prog, f);
        glLinkProgram(prog);
        glDeleteShader(v);
        glDeleteShader(f);
        GLint ok = 0;
        glGetProgramiv(prog, GL_LINK_STATUS, &ok);
        if (!ok) return false;
        u_size = glGetUniformLocation(prog, "size");
        glGenVertexArrays(1, &vao);
        glGenBuffers(1, &vbo);
        glBindVertexArray(vao);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferData(GL_ARRAY_BUFFER, sizeof verts, NULL, GL_DYNAMIC_DRAW);
        glEnableVertexAttribArray(0);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 6 * sizeof(float), (void*)0);
        glEnableVertexAttribArray(1);
        glVertexAttribPointer(1, 4, GL_FLOAT, GL_FALSE, 6 * sizeof(float), (void*)(2 * sizeof(float)));
        return true;
    }
    void rect(float x, float y, float w, float h, float r, float g, float b, float a = 1.f) {
        if (count >= kMax) return;  // a full batch drops quads; flush() earlier for bigger scenes
        const float px[6][2] = {{x, y}, {x + w, y}, {x + w, y + h}, {x, y}, {x + w, y + h}, {x, y + h}};
        float* o = verts + count * 36;
        for (int i = 0; i < 6; i++) {
            o[i * 6 + 0] = px[i][0];
            o[i * 6 + 1] = px[i][1];
            o[i * 6 + 2] = r;
            o[i * 6 + 3] = g;
            o[i * 6 + 4] = b;
            o[i * 6 + 5] = a;
        }
        count++;
    }
    void flush(float width, float height) {
        if (!count) return;
        glUseProgram(prog);
        glUniform2f(u_size, width, height);
        glBindVertexArray(vao);
        glBindBuffer(GL_ARRAY_BUFFER, vbo);
        glBufferSubData(GL_ARRAY_BUFFER, 0, (GLsizeiptr)(count * 36 * sizeof(float)), verts);
        glEnable(GL_BLEND);
        glBlendFunc(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
        glDrawArrays(GL_TRIANGLES, 0, count * 6);
        count = 0;
    }
    void destroy() {
        if (vbo) glDeleteBuffers(1, &vbo);
        if (vao) glDeleteVertexArrays(1, &vao);
        if (prog) glDeleteProgram(prog);
        vbo = vao = prog = 0;
    }

private:
    static GLuint compile(GLenum type, const char* src) {
        GLuint s = glCreateShader(type);
        glShaderSource(s, 1, &src, NULL);
        glCompileShader(s);
        GLint ok = 0;
        glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
        if (!ok) {
            glDeleteShader(s);
            return 0;
        }
        return s;
    }
};
