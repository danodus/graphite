#include "camera.h"
#include "matrix.h"

static camera_t camera;

void init_camera(vec3_t position, vec3_t direction, vec3_t forward_velocity, fix16_t yaw, fix16_t pitch) {
    camera.position = position;
    camera.direction = direction;
    camera.forward_velocity = forward_velocity;
    camera.yaw = yaw;
    camera.pitch = pitch;
}

vec3_t get_camera_position(void) {
    return camera.position;
}

void set_camera_position(vec3_t position) {
    camera.position = position;
}

vec3_t get_camera_direction(void) {
    return camera.direction;
}

void set_camera_direction(vec3_t direction) {
    camera.direction = direction;
}

vec3_t get_camera_forward_velocity(void) {
    return camera.forward_velocity;
}

void set_camera_forward_velocity(vec3_t forward_velocity) {
    camera.forward_velocity = forward_velocity;
}

fix16_t get_camera_yaw(void) {
    return camera.yaw;
}

void set_camera_yaw(fix16_t yaw) {
    camera.yaw = yaw;
}

fix16_t get_camera_pitch(void) {
    return camera.pitch;
}

void set_camera_pitch(fix16_t pitch) {
    camera.pitch = pitch;
}

vec3_t get_camera_lookat_target(void) {
    vec3_t target = { 0, 0, fix16_from_float(1) };

    mat4_t camera_yaw_rotation = mat4_make_rotation_y(get_camera_yaw());
    mat4_t camera_pitch_rotation = mat4_make_rotation_x(get_camera_pitch());

    mat4_t camera_rotation = mat4_identity();
    camera_rotation = mat4_mul_mat4(camera_rotation, camera_pitch_rotation);
    camera_rotation = mat4_mul_mat4(camera_rotation, camera_yaw_rotation);

    camera.direction = vec3_from_vec4(mat4_mul_vec4(camera_rotation, vec4_from_vec3(target)));

    // Offset the camera position in the direction where the camera is pointing at
    target = vec3_add(camera.position, camera.direction);
    return target;
}