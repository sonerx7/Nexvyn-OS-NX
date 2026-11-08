// OpenGL ES scene template: SDL2 window + EGL/GLES context, one shader, a spinning triangle.
#include <SDL.h>
#include <GLES2/gl2.h>
#include <switch.h>
#include <cmath>
#include <cstdio>

#ifdef NEXVYN_ABI
#include <nexvyn/nexvyn_native.h>
#endif

static const char* kVert =
    "attribute vec2 pos; attribute vec3 col; uniform float ang; varying vec3 v;\n"
    "void main(){ float c=cos(ang), s=sin(ang); gl_Position=vec4(c*pos.x-s*pos.y, (s*pos.x+c*pos.y)*1.777, 0.0, 1.0); v=col; }\n";
static const char* kFrag = "precision mediump float; varying vec3 v; void main(){ gl_FragColor=vec4(v,1.0); }\n";

static GLuint compile(GLenum type, const char* src) {
    GLuint s = glCreateShader(type);
    glShaderSource(s, 1, &src, nullptr);
    glCompileShader(s);
    GLint ok = 0;
    glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) {
        char log[512];
        glGetShaderInfoLog(s, sizeof log, nullptr, log);
        std::fprintf(stderr, "shader: %s\n", log);
    }
    return s;
}

int main(int, char**) {
    SDL_Init(SDL_INIT_VIDEO | SDL_INIT_JOYSTICK);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_PROFILE_MASK, SDL_GL_CONTEXT_PROFILE_ES);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MAJOR_VERSION, 2);
    SDL_GL_SetAttribute(SDL_GL_CONTEXT_MINOR_VERSION, 0);
    SDL_GL_SetAttribute(SDL_GL_DEPTH_SIZE, 24);
    SDL_Window* win = SDL_CreateWindow("@TITLE@", 0, 0, 1280, 720, SDL_WINDOW_OPENGL | SDL_WINDOW_FULLSCREEN);
    SDL_GLContext ctx = win ? SDL_GL_CreateContext(win) : nullptr;
    if (!ctx) { SDL_Quit(); return 1; }
    SDL_GL_SetSwapInterval(1);
    for (int i = 0; i < SDL_NumJoysticks(); i++) SDL_JoystickOpen(i);

    GLuint prog = glCreateProgram();
    glAttachShader(prog, compile(GL_VERTEX_SHADER, kVert));
    glAttachShader(prog, compile(GL_FRAGMENT_SHADER, kFrag));
    glBindAttribLocation(prog, 0, "pos");
    glBindAttribLocation(prog, 1, "col");
    glLinkProgram(prog);
    GLint angLoc = glGetUniformLocation(prog, "ang");

    static const float verts[] = {  // x y r g b
        0.0f, 0.5f, 1.0f, 0.3f, 0.2f,   -0.45f, -0.35f, 0.2f, 1.0f, 0.4f,   0.45f, -0.35f, 0.3f, 0.4f, 1.0f};

    bool run = true;
    while (run && appletMainLoop()) {
        SDL_Event e;
        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) run = false;
            if (e.type == SDL_JOYBUTTONDOWN && e.jbutton.button == 10) run = false;  // Plus
        }
        glViewport(0, 0, 1280, 720);
        glClearColor(0.06f, 0.07f, 0.12f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);
        glUseProgram(prog);
        glUniform1f(angLoc, SDL_GetTicks() * 0.001f);
        glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 20, verts);
        glVertexAttribPointer(1, 3, GL_FLOAT, GL_FALSE, 20, verts + 2);
        glEnableVertexAttribArray(0);
        glEnableVertexAttribArray(1);
        glDrawArrays(GL_TRIANGLES, 0, 3);
        SDL_GL_SwapWindow(win);
    }
    SDL_GL_DeleteContext(ctx);
    SDL_DestroyWindow(win);
    SDL_Quit();
    return 0;
}
