#include <SDL2/SDL.h>
#include <cube.h>
#include <stdbool.h>
#include <teapot.h>

#include "sw_rasterizer.h"

static int screen_width = 128;
static int screen_height = 128;
static int screen_scale = 4;

static SDL_Renderer* renderer;

void draw_pixel(int x, int y, int color) {
    float r = (float)((color >> 8) & 0xF) / 15.0f;
    float g = (float)((color >> 4) & 0xF) / 15.0f;
    float b = (float)((color >> 0) & 0xF) / 15.0f;

    SDL_SetRenderDrawColor(renderer, r * 255, g * 255, b * 255, SDL_ALPHA_OPAQUE);
    SDL_RenderDrawPoint(renderer, x, y);
}

void xd_draw_triangle(fx32 x0, fx32 y0, fx32 x1, fx32 y1, fx32 x2, fx32 y2, int color) {
    sw_draw_triangle(x0, y0, x1, y1, x2, y2, color);
}

void xd_draw_textured_triangle(fx32 x0, fx32 y0, fx32 z0, fx32 u0, fx32 v0, fx32 r0, fx32 g0, fx32 b0, fx32 a0, fx32 x1,
                               fx32 y1, fx32 z1, fx32 u1, fx32 v1, fx32 r1, fx32 g1, fx32 b1, fx32 a1, fx32 x2, fx32 y2,
                               fx32 z2, fx32 u2, fx32 v2, fx32 r2, fx32 g2, fx32 b2, fx32 a2, texture_t* tex) {
    sw_draw_textured_triangle(x0, y0, z0, u0, v0, r0, g0, b0, a0, x1, y1, z1, u1, v1, r1, g1, b1, a1, x2, y2, z2, u2,
                              v2, r2, g2, b2, a2, tex);
}

int main(int argc, char* argv[]) {
    sw_init_rasterizer(screen_width, screen_height, draw_pixel);

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

    float theta = 0.0f;

    model_t* cube_model = load_cube();
    model_t* teapot_model = load_teapot();
    model_t* current_model = cube_model;

    unsigned int time = SDL_GetTicks();

    float yaw = 0.0f;

    vec3d vec_up = {FX(0.0f), FX(1.0f), FX(0.0f), FX(1.0f)};
    vec3d vec_camera = {FX(0.0f), FX(0.0f), FX(0.0f), FX(1.0f)};
    while (!quit) {
        SDL_SetRenderDrawColor(renderer, 0, 0, 0, SDL_ALPHA_OPAQUE);
        SDL_RenderClear(renderer);
        sw_clear_depth_buffer();

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

        mat4x4 mat_trans = matrix_make_translation(FX(0.0f), FX(0.0f), FX(3.0f));
        mat4x4 mat_world;
        mat_world = matrix_make_identity();
        mat_world = matrix_multiply_matrix(&mat_rot_z, &mat_rot_x);
        mat_world = matrix_multiply_matrix(&mat_world, &mat_trans);

        // Draw cube
        draw_model(screen_width, screen_height, &vec_camera, current_model, &mat_world, &mat_proj, &mat_view, false,
                   false, NULL);

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
                    default:
                        // do nothing
                        break;
                }
            }
        }

        theta += 0.001f;
    }

    SDL_DestroyWindow(window);
    SDL_Quit();

    sw_dispose_rasterizer();

    return 0;
}
