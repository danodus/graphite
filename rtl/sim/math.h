#ifndef MATH_H
#define MATH_H

struct Vector3f {

    union {
        float x = 0.0f;
        float r;
    };

    union {
        float y = 0.0f;
        float g;
    };

    union {
        float z = 0.0f;
        float b;
    };
    
    Vector3f() {}
    Vector3f(float _x, float _y, float _z) {
        x = _x;
        y = _y;
        z = _z;
    }
};

#endif
