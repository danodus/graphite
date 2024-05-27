#ifndef _GL_H_
#define _GL_H_

#include <graphite.h>

typedef unsigned int GLenum;
typedef int GLfixed;
typedef unsigned int GLuint;
typedef size_t GLsizeiptr;
typedef unsigned int GLbitfield;
typedef int GLint;
typedef unsigned char GLboolean;
typedef int GLsizei;
typedef int GLclampx;

#define GL_DEPTH_BUFFER_BIT 0x00000100
#define GL_COLOR_BUFFER_BIT 0x00004000
#define GL_FALSE            0
#define GL_TRUE             1
#define GL_TRIANGLES        0x0004
#define GL_ARRAY_BUFFER     0x8892
#define GL_STATIC_DRAW      0x88E4

#ifdef __cplusplus
extern "C" {
#endif 

// Graphite extension
void gglSwap(GLboolean vsync);

void glBindBuffer(GLenum target, GLuint buffer);
void glBufferData(GLenum target, GLsizeiptr size, const void *data, GLenum usage);
void glClear(GLbitfield mask);
void glClearColorx(GLclampx red, GLclampx green, GLclampx blue, GLclampx alpha);
void glDeleteBuffers(GLsizei n, const GLuint *buffers);
void glDrawArrays(GLenum mode, GLint first, GLsizei count);
void glGenBuffers(GLsizei n, GLuint *buffers);
void glViewport(GLint x, GLint y, GLsizei width, GLsizei height);

#ifdef __cplusplus
}
#endif 

#endif // _GL_H_
