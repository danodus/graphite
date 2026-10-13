// graphite_ref_impl.c
// Copyright (c) 2021-2026 Daniel Cliche
// SPDX-License-Identifier: MIT

#include <SDL.h>
#include <cube.h>
#include <stdbool.h>
#include <teapot.h>

#include "sw_rasterizer.h"

static int screen_width = 320;
static int screen_height = 240;
static int screen_scale = 3;

static SDL_Renderer* renderer;

void draw_pixel(int x, int y, int color) {

    // Constants taken from https://stackoverflow.com/a/9069480

    int r5 = color >> 11;
    int g6 = (color >> 5) & 0x3F;
    int b5 = color & 0x1F;

    int r = (r5 * 527 + 23) >> 6;
    int g = (g6 * 259 + 33) >> 6;
    int b = (b5 * 527 + 23) >> 6;

    SDL_SetRenderDrawColor(renderer, r, g, b, SDL_ALPHA_OPAQUE);
    SDL_RenderDrawPoint(renderer, x, y);
}

void xd_draw_triangle(vec3d p[3], vec2d t[3], vec3d c[3], texture_t* tex, bool clamp_s, bool clamp_t, int texture_scale_x, int texture_scale_y,
                      bool depth_test, bool perspective_correct, const vec3d* sh, bool depth_only, bool enable_shadow)
{
    if (sh != NULL && (depth_only || enable_shadow))
        sw_set_triangle_shadow(depth_only, enable_shadow, sh[0].x, sh[0].y, sh[0].z, sh[1].x, sh[1].y, sh[1].z, sh[2].x, sh[2].y, sh[2].z);
    else
        sw_set_triangle_shadow(false, false, 0, 0, 0, 0, 0, 0, 0, 0, 0);
    sw_draw_triangle_standard(p[0].x, p[0].y, t[0].w, t[0].u, t[0].v, c[0].x, c[0].y, c[0].z, c[0].w, p[1].x, p[1].y, t[1].w, t[1].u, t[1].v, c[1].x, c[1].y, c[1].z, c[1].w, p[2].x, p[2].y, t[2].w, t[2].u, t[2].v, c[2].x, c[2].y, c[2].z, c[2].w, (tex != NULL) ? true : false, clamp_s, clamp_t, depth_test, perspective_correct, 0);
}

int main() {
    sw_init_rasterizer_standard(screen_width, screen_height, draw_pixel);

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
    model_t* floor_model = load_shadow_floor();
    model_t* current_model = cube_model;

    static uint16_t shadow_map[SHADOW_MAP_SIZE * SHADOW_MAP_SIZE];
    sw_bind_shadow_map(shadow_map, SHADOW_MAP_SIZE, SHADOW_BIAS);

    bool is_anim = false;
    bool is_wireframe = false;
    size_t nb_lights = 0;
    bool is_gouraud_shading = false;
    bool is_textured = true;
    bool clamp_s = false;
    bool clamp_t = false;
    bool perspective_correct = true;
    bool show_shadow = false;

    light_t lights[5];
    lights[0].direction = (vec3d){FX(0.0f), FX(0.0f), FX(1.0f), FX(0.0f)};
    lights[0].ambient_color = (vec3d){FX(0.1f), FX(0.1f), FX(0.1f), FX(1.0f)};
    lights[0].diffuse_color = (vec3d){FX(0.5f), FX(0.5f), FX(0.5f), FX(1.0f)};
    lights[1].direction = (vec3d){FX(1.0f), FX(0.0f), FX(0.0f), FX(0.0f)};
    lights[1].ambient_color = (vec3d){FX(0.1f), FX(0.0f), FX(0.0f), FX(1.0f)};
    lights[1].diffuse_color = (vec3d){FX(0.2f), FX(0.0f), FX(0.0f), FX(1.0f)};
    lights[2].direction = (vec3d){FX(0.0f), FX(1.0f), FX(0.0f), FX(0.0f)};
    lights[2].ambient_color = (vec3d){FX(0.0f), FX(0.1f), FX(0.0f), FX(1.0f)};
    lights[2].diffuse_color = (vec3d){FX(0.0f), FX(0.2f), FX(0.0f), FX(1.0f)};
    lights[3].direction = (vec3d){FX(0.0f), FX(-1.0f), FX(0.0f), FX(0.0f)};
    lights[3].ambient_color = (vec3d){FX(0.0f), FX(0.0f), FX(0.1f), FX(1.0f)};
    lights[3].diffuse_color = (vec3d){FX(0.0f), FX(0.0f), FX(0.2f), FX(1.0f)};
    lights[4].direction = (vec3d){FX(-1.0f), FX(0.0f), FX(0.0f), FX(0.0f)};
    lights[4].ambient_color = (vec3d){FX(0.1f), FX(0.1f), FX(0.0f), FX(1.0f)};
    lights[4].diffuse_color = (vec3d){FX(0.2f), FX(0.2f), FX(0.0f), FX(1.0f)};    

    unsigned int time = SDL_GetTicks();

    float yaw = 0.0f;

    vec3d vec_up = {FX(0.0f), FX(1.0f), FX(0.0f), FX(1.0f)};
    vec3d vec_camera = {FX(0.0f), FX(0.0f), FX(0.0f), FX(1.0f)};
    while (!quit) {
        float elapsed_time = (float)(SDL_GetTicks() - time) / 1000.0f;
        if (elapsed_time < 0.001f)
            elapsed_time = 0.001f;
        time = SDL_GetTicks();

        while (SDL_PollEvent(&e)) {
            if (e.type == SDL_QUIT) {
                quit = 1;
            } else if (e.type == SDL_KEYDOWN) {
                switch (e.key.keysym.scancode) {
                    case SDL_SCANCODE_ESCAPE:
                        quit = 1;
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
                        nb_lights = (nb_lights + 1) % 6;
                        break;
                    case SDL_SCANCODE_G:
                        is_gouraud_shading = !is_gouraud_shading;
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
                    case SDL_SCANCODE_M:
                        show_shadow = !show_shadow;
                        break;
                    case SDL_SCANCODE_KP_PLUS:
                        scale += 1.0f;
                        break;
                    case SDL_SCANCODE_KP_MINUS:
                        if (scale > 1.0f)
                            scale -= 1.0f;
                        break;
                    default:
                        break;
                }
            }
        }

        const Uint8* key_state = SDL_GetKeyboardState(NULL);
        if (key_state[SDL_SCANCODE_A])
            yaw -= 2.0f * elapsed_time;
        if (key_state[SDL_SCANCODE_D])
            yaw += 2.0f * elapsed_time;

        vec3d vec_look_forward = {FX(0.0f), FX(0.0f), FX(1.0f), FX(1.0f)};
        mat4x4 mat_camera_rot = matrix_make_rotation_y(yaw);
        vec3d vec_look_dir = matrix_multiply_vector(&mat_camera_rot, &vec_look_forward);
        // right = up × forward, so strafe stays perpendicular to the facing direction
        vec3d vec_right_dir = {vec_look_dir.z, FX(0.0f), -vec_look_dir.x, FX(1.0f)};
        vec3d vec_forward = vector_mul(&vec_look_dir, MUL(FX(2.0f), FX(elapsed_time)));
        vec3d vec_right = vector_mul(&vec_right_dir, MUL(FX(8.0f), FX(elapsed_time)));

        if (key_state[SDL_SCANCODE_UP])
            vec_camera.y += MUL(FX(8.0f), FX(elapsed_time));
        if (key_state[SDL_SCANCODE_DOWN])
            vec_camera.y -= MUL(FX(8.0f), FX(elapsed_time));
        if (key_state[SDL_SCANCODE_LEFT])
            vec_camera = vector_sub(&vec_camera, &vec_right);
        if (key_state[SDL_SCANCODE_RIGHT])
            vec_camera = vector_add(&vec_camera, &vec_right);
        if (key_state[SDL_SCANCODE_W])
            vec_camera = vector_add(&vec_camera, &vec_forward);
        if (key_state[SDL_SCANCODE_S])
            vec_camera = vector_sub(&vec_camera, &vec_forward);

        if (is_anim)
            theta += 0.01f;

        SDL_SetRenderDrawColor(renderer, 50, 50, 50, SDL_ALPHA_OPAQUE);
        SDL_RenderClear(renderer);
        sw_clear_depth_buffer_standard();

        //
        // camera
        //

        vec3d vec_target = vector_add(&vec_camera, &vec_look_dir);

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
        mat4x4 mat_world, mat_normal;
        mat_world = matrix_make_identity();
        mat_world = matrix_multiply_matrix(&mat_world, &mat_rot_z);
        mat_world = mat_normal = matrix_multiply_matrix(&mat_world, &mat_rot_x);
        mat_world = matrix_multiply_matrix(&mat_world, &mat_scale);
        mat_world = matrix_multiply_matrix(&mat_world, &mat_trans);

        vec3d light_pos;
        mat4x4 light_view, light_proj;
        shadow_draw_t sample_pass = {0};
        if (show_shadow) {
            sw_clear_shadow_map();
            shadow_make_light(&light_pos, &light_view, &light_proj);

            shadow_draw_t depth_pass = {0};
            depth_pass.z_near = FX(SHADOW_Z_NEAR);
            depth_pass.z_far = FX(SHADOW_Z_FAR);
            depth_pass.depth_only = true;
            draw_model(SHADOW_MAP_SIZE, SHADOW_MAP_SIZE, &light_pos, current_model, &mat_world, NULL, &light_proj, &light_view,
                       NULL, 0, false, NULL, false, false, 0, 0, false, &depth_pass);

            sample_pass.light_view = &light_view;
            sample_pass.light_proj = &light_proj;
            sample_pass.map_size = SHADOW_MAP_SIZE;
            sample_pass.z_near = FX(SHADOW_Z_NEAR);
            sample_pass.z_far = FX(SHADOW_Z_FAR);
            sample_pass.sample = true;
        }

        // Draw lines
        vec3d v0, v1, c0, c1;
        v0.x = FX(0.0f), v0.y = FX(0.0f), v0.z = FX(1.0f), v0.w = FX(1.0f);
        c0.x = FX(1.0f), c0.y = FX(1.0f), c0.z = FX(1.0f), c0.w = FX(1.0f);

        for(fx32 x = FX(0.0); x < FX(120.0f); x+=FX(10.0f)) {
            v1.x = x, v1.y = FX(140.0f), v1.z = FX(1.0f), v1.w = FX(1.0f);
            draw_line(v0, v1, (vec2d){FX(0.0f), FX(0.0f), FX(1.0f)}, (vec2d){FX(0.0f), FX(0.0f), FX(1.0f)}, c0, c0, FX(1.0f), NULL, true, true, 0, 0, perspective_correct);
        }

        // Draw model
        texture_t dummy_texture;
        draw_model(screen_width, screen_height, &vec_camera, current_model, &mat_world, is_gouraud_shading ? &mat_normal : NULL, &mat_proj, &mat_view, lights, nb_lights,
                   is_wireframe, is_textured ? &dummy_texture : NULL, clamp_s, clamp_t, 0, 0, perspective_correct, NULL);

        if (show_shadow) {
            mat4x4 mat_floor = matrix_make_identity();
            draw_model(screen_width, screen_height, &vec_camera, floor_model, &mat_floor, NULL, &mat_proj, &mat_view, NULL, 0,
                       false, NULL, false, false, 0, 0, perspective_correct, &sample_pass);
        }

        SDL_RenderPresent(renderer);
    }

    SDL_DestroyWindow(window);
    SDL_Quit();

    sw_dispose_rasterizer_standard();

    return 0;
}
