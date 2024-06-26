#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <math.h>
#include <SDL.h>
#include <sd_card.h>
#include <fat_filelib.h>
#include <libfixmath/fix16.h>

#include <upng.h>
#include "array.h"
#include "clipping.h"
#include "display.h"

#include "array.h"
#include "vector.h"
#include "matrix.h"
#include "light.h"
#include "camera.h"
#include "triangle.h"
#include "texture.h"
#include "mesh.h"

#ifndef M_PI
#define M_PI 3.141592654
#endif

sd_context_t sd_ctx;

int read_sector(uint32_t sector, uint8_t *buffer, uint32_t sector_count) {
    for (uint32_t i = 0; i < sector_count; ++i) {
        if (!sd_read_single_block(&sd_ctx, sector + i, buffer))
            return 0;
        buffer += SD_BLOCK_LEN;
    }
    return 1;
}

int write_sector(uint32_t sector, uint8_t *buffer, uint32_t sector_count) {
    for (uint32_t i = 0; i < sector_count; ++i) {
        if (!sd_write_single_block(&sd_ctx, sector + i, buffer))
            return 0;
        buffer += SD_BLOCK_LEN;
    }
    return 1;
}

///////////////////////////////////////////////////////////////////////////////
// Array of triangles that sould be rendered frame by frame
///////////////////////////////////////////////////////////////////////////////
triangle_t* triangles_to_render = NULL;

///////////////////////////////////////////////////////////////////////////////
// Global variables for execution status and game loop
///////////////////////////////////////////////////////////////////////////////
mat4_t world_matrix;
mat4_t proj_matrix;
mat4_t view_matrix;

bool is_running = false;
fix16_t delta_time = 0;
int previous_frame_time = 0;

///////////////////////////////////////////////////////////////////////////////
// Setup function to initialize variables and game objects
///////////////////////////////////////////////////////////////////////////////
void setup(void) {
    // Initialize render mode and triangle culling method
    set_render_method(RENDER_WIRE);
    set_cull_method(CULL_BACKFACE);

    // Initialize the camera
    init_camera(vec3_new(0, 0, fix16_from_float(-5)), vec3_new(0, 0, fix16_from_float(1)), vec3_new(0, 0, 0), 0, 0);

    // Initialize the scene light direction
    init_light(vec3_new(0, 0, fix16_from_float(1)));

    // Initialize the perspective projection matrix
    fix16_t aspectx = fix16_div(fix16_from_int(get_window_width()), fix16_from_int(get_window_height()));
    fix16_t aspecty = fix16_div(fix16_from_int(get_window_height()), fix16_from_int(get_window_width()));
    fix16_t fovy = fix16_from_float(M_PI / 3.0); // 60 deg
    fix16_t fovx = fix16_mul(fix16_atan(fix16_mul(fix16_tan(fix16_div(fovy, fix16_from_float(2))), aspectx)), fix16_from_float(2.0));
    fix16_t z_near = fix16_from_float(0.1);
    fix16_t z_far = fix16_from_float(100.0);
    proj_matrix = mat4_make_perspective(fovy, aspecty, z_near, z_far);

    init_frustum_planes(fovx, fovy, z_near, z_far);

    load_mesh("/assets/runway.obj", "/assets/runway.png", vec3_new(fix16_from_float(1), fix16_from_float(1), fix16_from_float(1)), vec3_new(0, fix16_from_float(-1.5), fix16_from_float(23)), vec3_new(0, 0, 0));
    load_mesh("/assets/f22.obj", "/assets/f22.png", vec3_new(fix16_from_float(1), fix16_from_float(1), fix16_from_float(1)), vec3_new(0, fix16_from_float(-1.3), fix16_from_float(5)), vec3_new(0, fix16_from_float(-M_PI/2), 0));
    load_mesh("/assets/efa.obj", "/assets/efa.png", vec3_new(fix16_from_float(1), fix16_from_float(1), fix16_from_float(1)), vec3_new(fix16_from_float(-2), fix16_from_float(-1.3), fix16_from_float(9)), vec3_new(0, fix16_from_float(-M_PI/2), 0));
    load_mesh("/assets/f117.obj", "/assets/f117.png", vec3_new(fix16_from_float(1), fix16_from_float(1), fix16_from_float(1)), vec3_new(fix16_from_float(2), fix16_from_float(-1.3), fix16_from_float(9)), vec3_new(0, fix16_from_float(-M_PI/2), 0));
}

///////////////////////////////////////////////////////////////////////////////
// Poll system events and handle keyboard input
///////////////////////////////////////////////////////////////////////////////
void process_input(void) {
    SDL_Event event;
    while (SDL_PollEvent(&event)) {
        switch (event.type) {
            case SDL_QUIT:
                is_running = false;
                break;
            case SDL_KEYDOWN:
                switch (event.key.keysym.sym) {
                    case SDLK_ESCAPE:
                        is_running = false;
                        break;
                    case SDLK_1:
                        set_render_method(RENDER_WIRE_VERTEX);
                        break;
                    case SDLK_2:
                        set_render_method(RENDER_WIRE);
                        break;
                    case SDLK_3:
                        set_render_method(RENDER_FILL_TRIANGLE);
                        break;
                    case SDLK_4:
                        set_render_method(RENDER_FILL_TRIANGLE_WIRE);
                        break;
                    case SDLK_5:
                        set_render_method(RENDER_TEXTURED);
                        break;
                    case SDLK_6:
                        set_render_method(RENDER_TEXTURED_WIRE);
                        break;
                    case SDLK_c:
                        set_cull_method(CULL_BACKFACE);
                        break;
                    case SDLK_x:
                        set_cull_method(CULL_NONE);
                        break;
                    case SDLK_LEFT: {
                        fix16_t camera_yaw = get_camera_yaw();
                        camera_yaw -= fix16_mul(fix16_from_float(0.1), delta_time);
                        set_camera_yaw(camera_yaw);
                        break;
                    }
                    case SDLK_RIGHT: {
                        fix16_t camera_yaw = get_camera_yaw();
                        camera_yaw += fix16_mul(fix16_from_float(0.1), delta_time);
                        set_camera_yaw(camera_yaw);
                        break;
                    }
                    case SDLK_s: {
                        fix16_t camera_pitch = get_camera_pitch();
                        camera_pitch -= fix16_mul(fix16_from_float(0.1), delta_time);
                        set_camera_pitch(camera_pitch);
                        break;
                    }
                    case SDLK_w: {
                        fix16_t camera_pitch = get_camera_pitch();
                        camera_pitch += fix16_mul(fix16_from_float(0.1), delta_time);
                        set_camera_pitch(camera_pitch);
                        break;
                    }
                    case SDLK_UP: {
                        set_camera_forward_velocity(vec3_mul(get_camera_direction(), fix16_mul(fix16_from_float(0.2), delta_time)));
                        set_camera_position(vec3_add(get_camera_position(), get_camera_forward_velocity()));
                        break;
                    }
                    case SDLK_DOWN:
                        set_camera_forward_velocity(vec3_mul(get_camera_direction(), fix16_mul(fix16_from_float(0.2), delta_time)));
                        set_camera_position(vec3_sub(get_camera_position(), get_camera_forward_velocity()));
                        break;
                }
                break;
        }
    }
}

///////////////////////////////////////////////////////////////////////////////
// Process the graphics pipeline stages for all the mesh triangles
///////////////////////////////////////////////////////////////////////////////
// +-------------+
// | Model space |  <-- original mesh vertices
// +-------------+
// |   +-------------+
// `-> | World space |  <-- multiply by world matrix
//     +-------------+
//     |   +--------------+
//     `-> | Camera space |  <-- multiply by view matrix
//         +--------------+
//         |    +------------+
//         `--> |  Clipping  |  <-- clip against the six frustum planes
//              +------------+
//              |    +------------+
//              `--> | Projection |  <-- multiply by projection matrix
//                   +------------+
//                   |    +-------------+
//                   `--> | Image space |  <-- apply perspective divide
//                        +-------------+
//                        |    +--------------+
//                        `--> | Screen space |  <-- ready to render
//                             +--------------+
///////////////////////////////////////////////////////////////////////////////
void process_graphics_pipeline_stages(mesh_t* mesh){
    // Create scale, rotation and translation matrix that will be used to multiply with the mesh vertices
    mat4_t scale_matrix = mat4_make_scale(mesh->scale.x, mesh->scale.y, mesh->scale.z);
    mat4_t translation_matrix = mat4_make_translation(mesh->translation.x, mesh->translation.y, mesh->translation.z);
    mat4_t rotation_matrix_x = mat4_make_rotation_x(mesh->rotation.x);
    mat4_t rotation_matrix_y = mat4_make_rotation_y(mesh->rotation.y);
    mat4_t rotation_matrix_z = mat4_make_rotation_z(mesh->rotation.z);

    // Initialize the target looking at the positive z-axis
    vec3_t target = get_camera_lookat_target();
    vec3_t up_direction = { 0, fix16_from_float(1), 0 };

    // Create the view matrix
    view_matrix = mat4_look_at(get_camera_position(), target, up_direction);

    // Loop all triangle faces of our mesh
    int num_faces = array_length(mesh->faces);
    for (int i = 0; i < num_faces; i++) {
        face_t mesh_face = mesh->faces[i];

        vec3_t face_vertices[3];
        face_vertices[0] = mesh->vertices[mesh_face.a - 1];
        face_vertices[1] = mesh->vertices[mesh_face.b - 1];
        face_vertices[2] = mesh->vertices[mesh_face.c - 1];

        vec4_t transformed_vertices[3];

        // Loop all three vertices of this current face and apply transformations
        for (int j = 0; j < 3; j++) {
            vec4_t transformed_vertex = vec4_from_vec3(face_vertices[j]);

            // Create a World Matrix combining scale, rotatio and translation matrices
            world_matrix = mat4_identity();
            world_matrix = mat4_mul_mat4(scale_matrix, world_matrix);
            world_matrix = mat4_mul_mat4(rotation_matrix_z, world_matrix);
            world_matrix = mat4_mul_mat4(rotation_matrix_y, world_matrix);
            world_matrix = mat4_mul_mat4(rotation_matrix_x, world_matrix);
            world_matrix = mat4_mul_mat4(translation_matrix, world_matrix);

            // Multiply the world matrix by the original vector
            transformed_vertex = mat4_mul_vec4(world_matrix, transformed_vertex);

            // Multiply the view matrix by the vector to transform the scene to camera space
            transformed_vertex = mat4_mul_vec4(view_matrix, transformed_vertex);

            // Save the transformed vertex in the array of transformed vertices
            transformed_vertices[j] = transformed_vertex;
        }

        // Compute the face normal (using the cross product to find perpendicular)
        vec3_t face_normal = get_triangle_normal(transformed_vertices);

        // Backface culling test to see if the current face should be projected
        if (get_cull_method() == CULL_BACKFACE) {

            // Find the vector between a point in the triangle and the camera origin
            vec3_t camera_ray = vec3_sub(vec3_new(0, 0, 0), vec3_from_vec4(transformed_vertices[0]));

            // Calculate how aligned the camera ray is with the face normal (using dot product)
            fix16_t dot_normal_camera = vec3_dot(face_normal, camera_ray);

            // Bypass the triangles that are looking away from the camera
            if (dot_normal_camera < fix16_from_float(0)) {
                continue;
            }
        }

        //
        // Clipping
        //

        // Create a polygon from the original transform
        polygon_t polygon = polygon_from_triangle(
            vec3_from_vec4(transformed_vertices[0]),
            vec3_from_vec4(transformed_vertices[1]),
            vec3_from_vec4(transformed_vertices[2]),
            mesh_face.a_uv,
            mesh_face.b_uv,
            mesh_face.c_uv
        );

        // Clip the polygon and return a new polygon with potential new vertices
        clip_polygon(&polygon);

        // Break the clipped polygon apart into individual triangles
        triangle_t triangles_after_clipping[MAX_NUM_POLY_TRIANGLES];
        int num_triangles_after_clipping = 0;

        triangles_from_polygon(&polygon, triangles_after_clipping, &num_triangles_after_clipping);
        
        // Loop all the assembled triangles after clipping
        for (int t = 0; t < num_triangles_after_clipping; t++) {
            triangle_t triangle_after_clipping = triangles_after_clipping[t];

            vec4_t projected_points[3];

            // Loop all three vertices to perform projection
            for (int j = 0; j < 3; j++) {
                // Project the current vertex
                projected_points[j] = mat4_mul_vec4_project(proj_matrix, triangle_after_clipping.points[j]);

                // Scale into the view
                projected_points[j].x = fix16_mul(projected_points[j].x, fix16_from_float(get_window_width() / 2.0));
                projected_points[j].y = fix16_mul(projected_points[j].y, fix16_from_float(get_window_height() / 2.0));

                // Invert the y values to account for flipped screen y coordinate
                projected_points[j].y = -projected_points[j].y;

                // Translate the projected points to the middle of the screen
                projected_points[j].x += fix16_from_float(get_window_width() / 2.0);
                projected_points[j].y += fix16_from_float(get_window_height() / 2.0);
            }

            // Calculate the shade intensity based on how aligned is the face normal and the inverse of the light direction
            fix16_t light_intensity_factor = -vec3_dot(get_light_direction(), face_normal);

            // Calculate the triangle color based on the light angle
            uint16_t triangle_color = light_apply_intensity(mesh_face.color, light_intensity_factor);

            triangle_t triangle_to_render = {
                .points = {
                    { projected_points[0].x, projected_points[0].y, projected_points[0].z,  projected_points[0].w },
                    { projected_points[1].x, projected_points[1].y, projected_points[1].z,  projected_points[1].w },
                    { projected_points[2].x, projected_points[2].y, projected_points[2].z,  projected_points[2].w }
                },
                .texcoords = {
                    { triangle_after_clipping.texcoords[0].u, triangle_after_clipping.texcoords[0].v },
                    { triangle_after_clipping.texcoords[1].u, triangle_after_clipping.texcoords[1].v },
                    { triangle_after_clipping.texcoords[2].u, triangle_after_clipping.texcoords[2].v }
                },
                .color = triangle_color,
                .texture = mesh->texture
            };

            // Save the projected triangle in the array of triangles to render
            array_push(triangles_to_render, triangle_to_render);
        }
    }
}

///////////////////////////////////////////////////////////////////////////////
// Update function
///////////////////////////////////////////////////////////////////////////////
void update(void) {

    int time_to_wait = FRAME_TARGET_TIME - (SDL_GetTicks() - previous_frame_time);

    if (time_to_wait > 0 && time_to_wait <= FRAME_TARGET_TIME) {
        SDL_Delay(time_to_wait);
    }

    // Get a delta time factor converted to seconds to be used to update our game objects
    delta_time = fix16_div(fix16_from_int(SDL_GetTicks() - previous_frame_time), fix16_from_float(1000.0));

    previous_frame_time = SDL_GetTicks();

    // Initialize the array of triangles to render
    triangles_to_render = NULL;

    // Loop all the meshes of our scene
    for (int mesh_index = 0; mesh_index < get_num_meshes(); mesh_index++) {
        mesh_t* mesh = get_mesh(mesh_index);

        // Change the mesh scale/rotation per animation frame
        //mesh->rotation.x += fix16_mul(fix16_from_float(0.1), delta_time);
        //mesh->translation.z = fix16_from_float(10.0);

        // Process the graphics pipeline stages for every mesh of our 3D scene
        process_graphics_pipeline_stages(mesh);
    }
}

///////////////////////////////////////////////////////////////////////////////
// Render function to draw objects on the display
///////////////////////////////////////////////////////////////////////////////
void render(void) {
    clear_color_buffer(0x0000);
    clear_z_buffer();

    draw_grid();

    // Loop all projected triangles and render them
    int num_triangles = array_length(triangles_to_render);
    for (int i = 0; i < num_triangles; i++) {
        triangle_t triangle = triangles_to_render[i];

        // Draw filled triangle
        if (get_render_method() == RENDER_FILL_TRIANGLE || get_render_method() == RENDER_FILL_TRIANGLE_WIRE) {
            draw_filled_triangle(
                fix16_to_int(triangle.points[0].x), fix16_to_int(triangle.points[0].y), triangle.points[0].z, triangle.points[0].w,
                fix16_to_int(triangle.points[1].x), fix16_to_int(triangle.points[1].y), triangle.points[1].z, triangle.points[1].w,
                fix16_to_int(triangle.points[2].x), fix16_to_int(triangle.points[2].y), triangle.points[2].z, triangle.points[2].w,
                triangle.color
            );
        }

        // Draw textured triangle
        if (get_render_method() == RENDER_TEXTURED || get_render_method() == RENDER_TEXTURED_WIRE) {
            draw_textured_triangle(
                fix16_to_int(triangle.points[0].x), fix16_to_int(triangle.points[0].y), triangle.points[0].z, triangle.points[0].w, triangle.texcoords[0].u, triangle.texcoords[0].v,
                fix16_to_int(triangle.points[1].x), fix16_to_int(triangle.points[1].y), triangle.points[1].z, triangle.points[1].w, triangle.texcoords[1].u, triangle.texcoords[1].v,
                fix16_to_int(triangle.points[2].x), fix16_to_int(triangle.points[2].y), triangle.points[2].z, triangle.points[2].w, triangle.texcoords[2].u, triangle.texcoords[2].v,
                triangle.texture
            );
        }

        // Draw unfilled triangle
        if (get_render_method() == RENDER_WIRE || get_render_method() == RENDER_WIRE_VERTEX || get_render_method() == RENDER_FILL_TRIANGLE_WIRE || get_render_method() == RENDER_TEXTURED_WIRE) {
            draw_triangle(
                fix16_to_int(triangle.points[0].x),
                fix16_to_int(triangle.points[0].y),
                fix16_to_int(triangle.points[1].x),
                fix16_to_int(triangle.points[1].y),
                fix16_to_int(triangle.points[2].x),
                fix16_to_int(triangle.points[2].y),
                0xFFFF
            );
        }

        // Draw triangle vertex points
        if (get_render_method() == RENDER_WIRE_VERTEX) {
            draw_rect(fix16_to_int(triangle.points[0].x) - 3, fix16_to_int(triangle.points[0].y) - 3, 6, 6, 0xFFF0);
            draw_rect(fix16_to_int(triangle.points[1].x) - 3, fix16_to_int(triangle.points[1].y) - 3, 6, 6, 0xFFF0);
            draw_rect(fix16_to_int(triangle.points[2].x) - 3, fix16_to_int(triangle.points[2].y) - 3, 6, 6, 0xFFF0);
        }
    }

    // Clear the array of triangles to render every frame loop
    array_free(triangles_to_render);

    render_color_buffer();
}

///////////////////////////////////////////////////////////////////////////////
// Free resources
///////////////////////////////////////////////////////////////////////////////
void free_resources(void) {
    free_meshes();
    destroy_window();
}

///////////////////////////////////////////////////////////////////////////////
// Main
///////////////////////////////////////////////////////////////////////////////
int main(void) {

    if (!sd_init(&sd_ctx)) {
        printf("SD card initialization failed.\r\n");
        return EXIT_FAILURE;
    }

    fl_init();

    // Attach media access functions to library
    if (fl_attach_media(read_sector, write_sector) != FAT_INIT_OK)
    {
        printf("Failed to init file system\r\n");
        return EXIT_FAILURE;
    }

    is_running = initialize_window();

    setup();

    while (is_running) {
        process_input();
        update();
        render();
    }

    destroy_window();
    free_resources();

    fl_shutdown();

    return EXIT_SUCCESS;
}
