#include <SDL.h>
#include <cube.h>
#include <stdbool.h>
#include <teapot.h>

#include "sw_rasterizer.h"

static int screen_width = 320;
static int screen_height = 240;
static int screen_scale = 3;

static SDL_Renderer* renderer;

bool g_rasterizer_barycentric = true;

void draw_pixel(int x, int y, int color) {
    float r = (float)((color >> 8) & 0xF) / 15.0f;
    float g = (float)((color >> 4) & 0xF) / 15.0f;
    float b = (float)((color >> 0) & 0xF) / 15.0f;

    SDL_SetRenderDrawColor(renderer, r * 255, g * 255, b * 255, SDL_ALPHA_OPAQUE);
    SDL_RenderDrawPoint(renderer, x, y);
}

void xd_draw_triangle(vec3d p[3], vec2d t[3], vec3d c[3], texture_t* tex, bool clamp_s, bool clamp_t,
                      bool depth_test, bool perspective_correct)
{
    if (g_rasterizer_barycentric) {
        sw_draw_triangle_barycentric(p[0].x, p[0].y, t[0].w, t[0].u, t[0].v, c[0].x, c[0].y, c[0].z, c[0].w, p[1].x, p[1].y, t[1].w, t[1].u, t[1].v, c[1].x, c[1].y, c[1].z, c[1].w, p[2].x, p[2].y, t[2].w, t[2].u, t[2].v, c[2].x, c[2].y, c[2].z, c[2].w, (tex != NULL) ? true : false, clamp_s, clamp_t, depth_test, perspective_correct);
    } else {
        sw_draw_triangle_standard(p[0].x, p[0].y, t[0].w, t[0].u, t[0].v, c[0].x, c[0].y, c[0].z, c[0].w, p[1].x, p[1].y, t[1].w, t[1].u, t[1].v, c[1].x, c[1].y, c[1].z, c[1].w, p[2].x, p[2].y, t[2].w, t[2].u, t[2].v, c[2].x, c[2].y, c[2].z, c[2].w, (tex != NULL) ? true : false, clamp_s, clamp_t, depth_test, perspective_correct);
    }
}

int main() {
    sw_init_rasterizer_standard(screen_width, screen_height, draw_pixel);
    sw_init_rasterizer_barycentric(screen_width, screen_height, draw_pixel);

    SDL_Init(SDL_INIT_VIDEO);

    SDL_Window* window =
        SDL_CreateWindow("Graphite Reference Implementation", SDL_WINDOWPOS_CENTERED_DISPLAY(1),
                         SDL_WINDOWPOS_UNDEFINED, screen_width * screen_scale, screen_height * screen_scale, 0);

    // SDL_SetWindowFullscreen(window, SDL_WINDOW_FULLSCREEN);

    renderer = SDL_CreateRenderer(window, -1, SDL_RENDERER_SOFTWARE);
    SDL_RenderSetScale(renderer, (float)screen_scale, (float)screen_scale);

    SDL_Event e;
    int quit = 0;

    // Projection matrix
    mat4x4 mat_proj = matrix_make_projection(screen_width, screen_height, 60.0f);

    float theta = 0.5f;
    float scale = 1.0f;

    model_t* cube_model = load_cube();
    model_t* teapot_model = load_teapot();
    model_t* current_model = cube_model;

    bool is_anim = false;
    bool is_wireframe = false;
    bool is_lighting = false;
    bool is_textured = true;
    bool clamp_s = false;
    bool clamp_t = false;
    bool perspective_correct = true;

    unsigned int time = SDL_GetTicks();

    float yaw = 0.0f;

    vec3d vec_up = {FX(0.0f), FX(1.0f), FX(0.0f), FX(1.0f)};
    vec3d vec_camera = {FX(0.0f), FX(0.0f), FX(0.0f), FX(1.0f)};
    while (!quit) {
        SDL_SetRenderDrawColor(renderer, 50, 50, 50, SDL_ALPHA_OPAQUE);
        SDL_RenderClear(renderer);
        if (g_rasterizer_barycentric) {
            sw_clear_depth_buffer_barycentric();
        } else {
            sw_clear_depth_buffer_standard();
        }

        //
        // camera
        //

        vec3d vec_target = {FX(0.0f), FX(0.0f), FX(1.0f), FX(1.0f)};
        mat4x4 mat_camera_rot = matrix_make_rotation_y(yaw);
        vec3d vec_look_dir = matrix_multiply_vector(&mat_camera_rot, &vec_target);
        vec_target = vector_add(&vec_camera, &vec_look_dir);

        mat4x4 mat_camera = matrix_point_at(&vec_camera, &vec_target, &vec_up);

        // make view matrix from camera
        mat4x4 mat_view = matrix_quick_inverse(&mat_camera);

        //
        // world
        //

        mat4x4 mat_rot_z = matrix_make_rotation_z(theta);
        mat4x4 mat_rot_x = matrix_make_rotation_x(theta);
        mat4x4 mat_scale = matrix_make_scale(FX(scale), FX(scale), FX(scale));
        mat4x4 mat_trans = matrix_make_translation(FX(0.0f), FX(0.0f), FX(2.0f));
        mat4x4 mat_world;
        mat_world = matrix_make_identity();
        mat_world = matrix_multiply_matrix(&mat_world, &mat_scale);
        mat_world = matrix_multiply_matrix(&mat_world, &mat_rot_z);
        mat_world = matrix_multiply_matrix(&mat_world, &mat_rot_x);
        mat_world = matrix_multiply_matrix(&mat_world, &mat_trans);

        // Draw lines
        vec3d v0, v1, c0, c1;
        v0.x = FX(0.0f), v0.y = FX(0.0f), v0.z = FX(1.0f), v0.w = FX(1.0f);
        c0.x = FX(1.0f), c0.y = FX(1.0f), c0.z = FX(1.0f), c0.w = FX(1.0f);

        for(fx32 x = FX(0.0); x < FX(120.0f); x+=FX(10.0f)) {
            v1.x = x, v1.y = FX(140.0f), v1.z = FX(1.0f), v1.w = FX(1.0f);
            draw_line(v0, v1, (vec2d){FX(0.0f), FX(0.0f), FX(0.0f)}, (vec2d){FX(0.0f), FX(0.0f), FX(0.0f)}, c0, c0, FX(1.0f), NULL, true, true, perspective_correct);
        }

        // Draw model
        texture_t dummy_texture;
        draw_model(screen_width, screen_height, &vec_camera, current_model, &mat_world, &mat_proj, &mat_view, is_lighting,
                   is_wireframe, is_textured ? &dummy_texture : NULL, clamp_s, clamp_t, perspective_correct);

        SDL_RenderPresent(renderer);

        // printf("%d ms\n", SDL_GetTicks() - time);
        float elapsed_time = (float)(SDL_GetTicks() - time) / 1000.0f;
        time = SDL_GetTicks();

        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) {
                quit = 1;
            } else if (e.type == SDL_KEYDOWN) {
                vec3d vec_forward = vector_mul(&vec_look_dir, MUL(FX(2.0f), FX(elapsed_time)));
                switch (e.key.keysym.scancode) {
                    case SDL_SCANCODE_ESCAPE:
                        quit = 1;
                        break;

                    case SDL_SCANCODE_UP:
                        vec_camera.y += MUL(FX(8.0f), FX(elapsed_time));
                        break;
                    case SDL_SCANCODE_DOWN:
                        vec_camera.y -= MUL(FX(8.0f), FX(elapsed_time));
                        break;
                    case SDL_SCANCODE_LEFT:
                        vec_camera.x -= MUL(FX(8.0f), FX(elapsed_time));
                        break;
                    case SDL_SCANCODE_RIGHT:
                        vec_camera.x += MUL(FX(8.0f), FX(elapsed_time));
                        break;
                    case SDL_SCANCODE_W:
                        vec_camera = vector_add(&vec_camera, &vec_forward);
                        break;
                    case SDL_SCANCODE_S:
                        vec_camera = vector_sub(&vec_camera, &vec_forward);
                        break;
                    case SDL_SCANCODE_A:
                        yaw -= 2.0f * elapsed_time;
                        break;
                    case SDL_SCANCODE_D:
                        yaw += 2.0f * elapsed_time;
                        break;
                    case SDL_SCANCODE_1:
                        current_model = cube_model;
                        break;
                    case SDL_SCANCODE_2:
                        current_model = teapot_model;
                        break;
                    case SDL_SCANCODE_TAB:
                        is_wireframe = !is_wireframe;
                        break;
                    case SDL_SCANCODE_L:
                        is_lighting = !is_lighting;
                        break;
                    case SDL_SCANCODE_T:
                        is_textured = !is_textured;
                        break;
                    case SDL_SCANCODE_U:
                        clamp_s = !clamp_s;
                        break;
                    case SDL_SCANCODE_V:
                        clamp_t = !clamp_t;
                        break;
                    case SDL_SCANCODE_P:
                        perspective_correct = !perspective_correct;
                        break;                                                                                        
                    case SDL_SCANCODE_SPACE:
                        is_anim = !is_anim;
                        break;
                    case SDL_SCANCODE_KP_PLUS:
                        scale += 1.0f;
                        break;
                    case SDL_SCANCODE_KP_MINUS:
                        if (scale > 1.0f)
                            scale -= 1.0f;
                        break;                        
                    case SDL_SCANCODE_BACKSLASH:
                        g_rasterizer_barycentric = !g_rasterizer_barycentric;
                        if (g_rasterizer_barycentric) {
                            printf("Barycentric\n");
                        } else {
                            printf("Standard\n");
                        }
                        break;
                    default:
                        // do nothing
                        break;
                }
            }
        }

        if (is_anim) theta += 0.01f;
    }

    SDL_DestroyWindow(window);
    SDL_Quit();

    sw_dispose_rasterizer_barycentric();
    sw_dispose_rasterizer_standard();

    return 0;
}
