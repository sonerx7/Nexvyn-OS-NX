// Amber gate: confirm while the rotating tetrahedron faces forward to score.
// Four faces, one draw call, no model downloads. Enter / confirm / touch scores.
#include <glad/glad.h>
#include <cmath>
#include <cstdio>
#include "window.h"
static GLuint shader(GLenum type, const char* text) {
    GLuint s = glCreateShader(type);
    glShaderSource(s, 1, &text, nullptr); glCompileShader(s);
    GLint ok = 0; glGetShaderiv(s, GL_COMPILE_STATUS, &ok);
    if (!ok) { glDeleteShader(s); return 0; }
    return s;
}
static int play(int, char**) {
    Window win;
    if (!win.open()) return 1;
    if (!gladLoadGLLoader((GLADloadproc)nxn_display_proc)) { win.close(); return 1; }
    const char* vs = "#version 330 core\nlayout(location=0) in vec3 p; uniform float angle; uniform float aspect; out vec3 col; void main(){float c=cos(angle),s=sin(angle); vec3 q=vec3(c*p.x+s*p.z,p.y,-s*p.x+c*p.z); col=p*.35+.6; gl_Position=vec4(q.x/aspect,q.y,q.z*.15,q.z+3.0);}";
    const char* fs = "#version 330 core\nin vec3 col; out vec4 color; void main(){color=vec4(col,1);}";
    GLuint v = shader(GL_VERTEX_SHADER, vs), f = shader(GL_FRAGMENT_SHADER, fs);
    if (!v || !f) { if(v) glDeleteShader(v); if(f) glDeleteShader(f); win.close(); return 1; }
    GLuint program = glCreateProgram(); glAttachShader(program,v); glAttachShader(program,f); glLinkProgram(program);
    glDeleteShader(v); glDeleteShader(f);
    GLint ok = 0; glGetProgramiv(program,GL_LINK_STATUS,&ok);
    if (!ok) { glDeleteProgram(program); win.close(); return 1; }
    const float vertices[] = {0,1,0, -1,-1,1, 1,-1,1, 0,1,0, 1,-1,1, 0,-1,-1, 0,1,0, 0,-1,-1, -1,-1,1, -1,-1,1, 0,-1,-1, 1,-1,1};
    GLuint vao, buffer; glGenVertexArrays(1,&vao); glBindVertexArray(vao);
    glGenBuffers(1,&buffer); glBindBuffer(GL_ARRAY_BUFFER,buffer);
    glBufferData(GL_ARRAY_BUFFER,sizeof vertices,vertices,GL_STATIC_DRAW);
    glVertexAttribPointer(0,3,GL_FLOAT,GL_FALSE,0,nullptr); glEnableVertexAttribArray(0);
    GLint angle_loc = glGetUniformLocation(program,"angle"), aspect_loc = glGetUniformLocation(program,"aspect");
    float angle = 0; int score = 0; uint64_t last = nxn_time_ns();
    while (win.tick()) {
        uint64_t now = nxn_time_ns(); float dt = fminf((now-last)/1e9f,.05f); last = now;
        if (!win.active()) { nxn_sleep_ns(16000000); continue; }
        angle = fmodf(angle + dt, 6.2831853f);
        bool aligned = cosf(angle) > .8f;
        if (win.confirm) {
            score = aligned ? score + 1 : 0;
            char n[20], text[96]; snprintf(n,sizeof n,"%d",score); const char* args[] = {n};
            nxn_tr_format("score",text,sizeof text,args,1);
            nxn_window_set_title(nxn_tr("title"),text);
        }
        glViewport(0,0,win.w,win.h); glEnable(GL_DEPTH_TEST);
        glClearColor(aligned ? .2f : .04f,.08f,.12f,1); glClear(GL_COLOR_BUFFER_BIT|GL_DEPTH_BUFFER_BIT);
        glUseProgram(program); glUniform1f(angle_loc,angle); glUniform1f(aspect_loc,(float)win.w/(win.h ? win.h : 1));
        glBindVertexArray(vao); glDrawArrays(GL_TRIANGLES,0,12); nxn_display_swap(win.display);
    }
    glDeleteBuffers(1,&buffer); glDeleteVertexArrays(1,&vao); glDeleteProgram(program); win.close(); return 0;
}
int main(int argc,char** argv) { return nxn_run(argc,argv,play,nullptr); }
