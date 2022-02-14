import matplotlib.pyplot as plt
import numpy as np

scale = 16


def _float_to_fixed(x: float, scale: np.int32) -> np.int32:
    return np.int32(x * float(1 << scale))


def _fixed_to_float(x: np.int32, scale: np.int32) -> float:
    return float(x) / float(1 << scale)


def _mul2(x: np.int32, y: np.int32, scale: np.int32) -> np.int32:
    return np.int32(np.int32(x >> np.int32(scale)) * np.int32(y >> np.int32(0)))


def _div(x: np.int32, y: np.int32, scale: np.int32) -> np.int32:
    return np.int32(np.int32(x << np.int32(scale / 2)) / np.int32(y >> np.int32(scale / 2)))


def _div2(x: np.int32, y: np.int32, scale: np.int32) -> np.int32:
    return np.int32(np.int32(x << np.int32(0)) / np.int32(y >> np.int32(scale)))


def fx(x: float) -> np.int32:
    return _float_to_fixed(x, scale)


def flt(x: np.int32) -> float:
    return _fixed_to_float(x, scale)


def mul2(x: np.int32, y: np.int32) -> np.int32:
    return _mul2(x, y, scale)


def div2(x: np.int32, y: np.int32) -> np.int32:
    return _div2(x, y, scale)


fx_v = np.vectorize(fx)
flt_v = np.vectorize(flt)
mul2_v = np.vectorize(mul2)
div2_v = np.vectorize(div2)

area = np.arange(1, 32768, 1.0)

ref_inv_area = 1.0/area
fx_inv_area = div2_v(fx(1.0), fx_v(area))

ref_one = area * ref_inv_area
fx_one = mul2_v(fx_v(area), fx_inv_area)

plt.plot(area, ref_inv_area, 'r', area, flt_v(
    fx_inv_area), 'b', area, flt_v(fx_one), 'g')
plt.show()
