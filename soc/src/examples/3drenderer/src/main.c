#include <stdio.h>
#include <stdint.h>
#include <stdbool.h>
#include <SDL.h>
#include <sd_card.h>
#include <fat_filelib.h>
#include "upng.h"
#include "array.h"
#include "display.h"
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
float delta_time = 0;
int previous_frame_time = 0;

enum cull_method {
    CULL_NONE,
    CULL_BACKFACE
} cull_method;

enum render_method {
    RENDER_WIRE,
    RENDER_WIRE_VERTEX,
    RENDER_FILL_TRIANGLE,
    RENDER_FILL_TRIANGLE_WIRE,
    RENDER_TEXTURED,
    RENDER_TEXTURED_WIRE
} render_method;

///////////////////////////////////////////////////////////////////////////////
// Setup function to initialize variables and game objects
///////////////////////////////////////////////////////////////////////////////
void setup(void) {
    // Initialize render mode and triangle culling method
    render_method = RENDER_WIRE;
    cull_method = CULL_BACKFACE;

    // Allocate the required memory in bytes to hold the color buffer
    color_buffer = (uint16_t*)malloc(sizeof(uint16_t) * window_width * window_height);
    z_buffer = (float*)malloc(sizeof(float) * window_width * window_height);

    // Creating a SDL texture that is used to display the color buffer
    color_buffer_texture = SDL_CreateTexture(
        renderer,
        SDL_PIXELFORMAT_ARGB4444,
        SDL_TEXTUREACCESS_STREAMING,
        window_width,
        window_height
    );

    // Initialize the perspective projection matrix
    float fov = M_PI / 3.0; // 60 deg
    float aspect = (float)window_height / (float)window_width;
    float znear = 0.1;
    float zfar = 100.0;
    proj_matrix = mat4_make_perspective(fov, aspect, znear, zfar);

    // Loads the values in the mesh data structures
    load_obj_file_data("/assets/f22.obj");

    // Load the texture information from an external PNG file
    load_png_texture_data("/assets/f22.png");
}

///////////////////////////////////////////////////////////////////////////////
// Poll system events and handle keyboard input
///////////////////////////////////////////////////////////////////////////////
void process_input(void) {
    SDL_Event event;
    SDL_PollEvent(&event);

    switch (event.type) {
        case SDL_QUIT:
            is_running = false;
            break;
        case SDL_KEYDOWN:
            if (event.key.keysym.sym == SDLK_ESCAPE)
                is_running = false;
            if (event.key.keysym.sym == SDLK_1)
                render_method = RENDER_WIRE_VERTEX;
            if (event.key.keysym.sym == SDLK_2)
                render_method = RENDER_WIRE;
            if (event.key.keysym.sym == SDLK_3)
                render_method = RENDER_FILL_TRIANGLE;
            if (event.key.keysym.sym == SDLK_4)
                render_method = RENDER_FILL_TRIANGLE_WIRE;
            if (event.key.keysym.sym == SDLK_5)
                render_method = RENDER_TEXTURED;
            if (event.key.keysym.sym == SDLK_6)
                render_method = RENDER_TEXTURED_WIRE;
            if (event.key.keysym.sym == SDLK_c)
                cull_method = CULL_BACKFACE;
            if (event.key.keysym.sym == SDLK_x)
                cull_method = CULL_NONE;
            if (event.key.keysym.sym == SDLK_UP)
                camera.position.y += 3.0 * delta_time;
            if (event.key.keysym.sym == SDLK_DOWN)
                camera.position.y -= 3.0 * delta_time;
            if (event.key.keysym.sym == SDLK_a)
                camera.yaw -= 1.0 * delta_time;
            if (event.key.keysym.sym == SDLK_d)
                camera.yaw += 1.0 * delta_time;
            if (event.key.keysym.sym == SDLK_w) {
                camera.forward_velocity = vec3_mul(camera.direction, 5.0 * delta_time);
                camera.position = vec3_add(camera.position, camera.forward_velocity);
            }
            if (event.key.keysym.sym == SDLK_s) {
                camera.forward_velocity = vec3_mul(camera.direction, 5.0 * delta_time);
                camera.position = vec3_sub(camera.position, camera.forward_velocity);
            }
            break;
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
    delta_time = (SDL_GetTicks() - previous_frame_time) / 1000.0;

    previous_frame_time = SDL_GetTicks();

    // Initialize the array of triangles to render
    triangles_to_render = NULL;

    // Change the mesh scale/rotation per animation frame
    mesh.rotation.x -= 0.05 * delta_time;
    //mesh.rotation.y += 0.5 * delta_time;
    //mesh.rotation.z += 0.02 * delta_time;
    //mesh.scale.x += 0.02;
    //mesh.scale.y += 0.01;
    //mesh.translation.x += 0.1 * delta_time;
    mesh.translation.z = 4.0;

    // Create scale, rotation and translation matrix that will be used to multiply with the mesh vertices
    mat4_t scale_matrix = mat4_make_scale(mesh.scale.x, mesh.scale.y, mesh.scale.z);
    mat4_t translation_matrix = mat4_make_translation(mesh.translation.x, mesh.translation.y, mesh.translation.z);
    mat4_t rotation_matrix_x = mat4_make_rotation_x(mesh.rotation.x);
    mat4_t rotation_matrix_y = mat4_make_rotation_y(mesh.rotation.y);
    mat4_t rotation_matrix_z = mat4_make_rotation_z(mesh.rotation.z);

    // Initialize the target looking at the positive z-axis
    vec3_t target = { 0, 0, 1 };
    mat4_t camera_yaw_rotation = mat4_make_rotation_y(camera.yaw);
    camera.direction = vec3_from_vec4(mat4_mul_vec4(camera_yaw_rotation, vec4_from_vec3(target)));

    // Offset the camera position in the direction where the camera is pointing at
    target = vec3_add(camera.position, camera.direction);
    vec3_t up_direction = { 0, 1, 0 };

    // Create the view matrix
    view_matrix = mat4_look_at(camera.position, target, up_direction);

    // Loop all triangle faces of our mesh
    int num_faces = array_length(mesh.faces);
    for (int i = 0; i < num_faces; i++) {
        face_t mesh_face = mesh.faces[i];

        vec3_t face_vertices[3];
        face_vertices[0] = mesh.vertices[mesh_face.a - 1];
        face_vertices[1] = mesh.vertices[mesh_face.b - 1];
        face_vertices[2] = mesh.vertices[mesh_face.c - 1];

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
        vec3_t normal;

        vec3_t vector_a = vec3_from_vec4(transformed_vertices[0]); /*   A   */
        vec3_t vector_b = vec3_from_vec4(transformed_vertices[1]); /*  / \  */
        vec3_t vector_c = vec3_from_vec4(transformed_vertices[2]); /* C---B */

        // Get the vector substraction of B-A and C-A
        vec3_t vector_ab = vec3_sub(vector_b, vector_a);
        vec3_t vector_ac = vec3_sub(vector_c, vector_a);
        vec3_normalize(&vector_ab);
        vec3_normalize(&vector_ac);

        normal = vec3_cross(vector_ab, vector_ac);
        vec3_normalize(&normal);        

        // Backface culling test to see if the current face should be projected
        if (cull_method == CULL_BACKFACE) {

            // Find the vector between a point in the triangle and the camera origin
            vec3_t origin = { 0, 0, 0 };
            vec3_t camera_ray = vec3_sub(origin, vector_a);

            // Calculate how aligned the camera ray is with the face normal (using dot product)
            float dot_normal_camera = vec3_dot(normal, camera_ray);

            // Bypass the triangles that are looking away from the camera
            if (dot_normal_camera < 0) {
                continue;
            }
        }

        vec4_t projected_points[3];

        // Loop all three vertices to perform projection
        for (int j = 0; j < 3; j++) {
            // Project the current vertex
            projected_points[j] = mat4_mul_vec4_project(proj_matrix, transformed_vertices[j]);

            // Scale into the view
            projected_points[j].x *= (window_width / 2.0);
            projected_points[j].y *= (window_height / 2.0);

            // Invert the y values to account for flipped screen y coordinate
            projected_points[j].y *= -1;

            // Translate the projected points to the middle of the screen
            projected_points[j].x += (window_width / 2.0);
            projected_points[j].y += (window_height / 2.0);
        }

        // Calculate the shade intensity based on how aligned is the face normal and the inverse of the light direction
        float light_intensity_factor = -vec3_dot(light.direction, normal);

        // Calculate the triangle color based on the light angle
        uint16_t triangle_color = light_apply_intensity(mesh_face.color, light_intensity_factor);

        triangle_t projected_triangle = {
            .points = {
                { projected_points[0].x, projected_points[0].y, projected_points[0].z,  projected_points[0].w },
                { projected_points[1].x, projected_points[1].y, projected_points[1].z,  projected_points[1].w },
                { projected_points[2].x, projected_points[2].y, projected_points[2].z,  projected_points[2].w }
            },
            .texcoords = {
                { mesh_face.a_uv.u, mesh_face.a_uv.v },
                { mesh_face.b_uv.u, mesh_face.b_uv.v },
                { mesh_face.c_uv.u, mesh_face.c_uv.v }
            },
            .color = triangle_color
        };

        // Save the projected triangle in the array of triangles to render
        array_push(triangles_to_render, projected_triangle);
    }
}

///////////////////////////////////////////////////////////////////////////////
// Render function to draw objects on the display
///////////////////////////////////////////////////////////////////////////////
void render(void) {
    clear_color_buffer(0xF000);
    clear_z_buffer();

    draw_grid();

    // Loop all projected triangles and render them
    int num_triangles = array_length(triangles_to_render);
    for (int i = 0; i < num_triangles; i++) {
        triangle_t triangle = triangles_to_render[i];

        // Draw filled triangle
        if (render_method == RENDER_FILL_TRIANGLE || render_method == RENDER_FILL_TRIANGLE_WIRE) {
            draw_filled_triangle(
                triangle.points[0].x, triangle.points[0].y, triangle.points[0].z, triangle.points[0].w,
                triangle.points[1].x, triangle.points[1].y, triangle.points[1].z, triangle.points[1].w,
                triangle.points[2].x, triangle.points[2].y, triangle.points[2].z, triangle.points[2].w,
                triangle.color
            );
        }

        // Draw textured triangle
        if (render_method == RENDER_TEXTURED || render_method == RENDER_TEXTURED_WIRE) {
            draw_textured_triangle(
                triangle.points[0].x, triangle.points[0].y, triangle.points[0].z, triangle.points[0].w, triangle.texcoords[0].u, triangle.texcoords[0].v,
                triangle.points[1].x, triangle.points[1].y, triangle.points[1].z, triangle.points[1].w, triangle.texcoords[1].u, triangle.texcoords[1].v,
                triangle.points[2].x, triangle.points[2].y, triangle.points[2].z, triangle.points[2].w, triangle.texcoords[2].u, triangle.texcoords[2].v,
                mesh_texture
            );
        }

        // Draw unfilled triangle
        if (render_method == RENDER_WIRE || render_method == RENDER_WIRE_VERTEX || render_method == RENDER_FILL_TRIANGLE_WIRE || render_method == RENDER_TEXTURED_WIRE) {
            draw_triangle(
                triangle.points[0].x,
                triangle.points[0].y,
                triangle.points[1].x,
                triangle.points[1].y,
                triangle.points[2].x,
                triangle.points[2].y,
                0xFFFF
            );
        }

        // Draw triangle vertex points
        if (render_method == RENDER_WIRE_VERTEX) {
            draw_rect(triangle.points[0].x - 3, triangle.points[0].y - 3, 6, 6, 0xFFF0);
            draw_rect(triangle.points[1].x - 3, triangle.points[1].y - 3, 6, 6, 0xFFF0);
            draw_rect(triangle.points[2].x - 3, triangle.points[2].y - 3, 6, 6, 0xFFF0);
        }
    }

    // Clear the array of triangles to render every frame loop
    array_free(triangles_to_render);

    render_color_buffer();

    SDL_RenderPresent(renderer);
}

///////////////////////////////////////////////////////////////////////////////
// Free resources
///////////////////////////////////////////////////////////////////////////////
void free_resources(void) {
    free(z_buffer);
    free(color_buffer);
    upng_free(png_texture);
    array_free(mesh.faces);
    array_free(mesh.vertices);
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
