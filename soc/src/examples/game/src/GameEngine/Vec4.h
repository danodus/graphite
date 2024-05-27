#pragma once

#include <graphite.h>

class Vec4 {
public:
    Vec4() {
    }
    Vec4(fx32 x, fx32 y, fx32 z, fx32 w) {
        v.x = x;
        v.y = y;
        v.z = z;
        v.w = w;
    }
    ~Vec4() {
    }

    fx32 x() const {
        return v.x;
    }

    fx32 y() const {
        return v.y;
    }

    fx32 z() const {
        return v.z;
    }

    fx32 w() const {
        return v.w;
    }

private:
    vec3d v;
};