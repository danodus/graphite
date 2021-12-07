#include <verilated.h>

#include <iostream>
#include <limits>

#include "Vtop.h"

void pulse_clk(Vtop* top) {
    top->contextp()->timeInc(1);
    top->clk = 1;
    top->eval();

    top->contextp()->timeInc(1);
    top->clk = 0;
    top->eval();
}

bool test_float_to_int(Vtop* top, float v) {
    top->op = 0;
    top->a_value_i = *(reinterpret_cast<int*>(&v));
    top->exec_strobe_i = 1;
    while (!top->contextp()->gotFinish() && !top->done_strobe_o) pulse_clk(top);
    top->exec_strobe_i = 0;
    pulse_clk(top);

    int r = top->z_value_o;
    int e = static_cast<int>(v);
    if (e != r) {
        std::cout << "float_to_int failure with float " << v << " - expected: " << e << ", received: " << r << "\n";
        return false;
    }

    return true;
}

bool test_int_to_float(Vtop* top, int v) {
    top->op = 1;
    top->a_value_i = v;
    top->exec_strobe_i = 1;
    while (!top->contextp()->gotFinish() && !top->done_strobe_o) pulse_clk(top);
    top->exec_strobe_i = 0;
    pulse_clk(top);

    int ri = top->z_value_o;
    float r = *(reinterpret_cast<float*>(&ri));
    float e = static_cast<float>(v);
    if (e != r) {
        std::cout << "int_to_float failure with int " << v << " - expected: " << e << ", received: " << r << "\n";
        return false;
    }

    return true;
}

int main(int argc, char** argv, char** env) {
    const std::unique_ptr<VerilatedContext> contextp{new VerilatedContext};

    Vtop* top = new Vtop{contextp.get(), "TOP"};

    top->reset_i = 1;

    contextp->timeInc(1);
    top->clk = 0;
    top->eval();

    contextp->timeInc(1);
    top->clk = 1;
    top->eval();

    contextp->timeInc(1);
    top->clk = 0;
    top->eval();

    top->reset_i = 0;

    bool success = true;

    std::vector<float> values{
        0.0f, 1.0f, -1.0f, 42.0f, std::numeric_limits<float>::min(), std::numeric_limits<float>::max()};
    for (auto v : values) {
        success = test_float_to_int(top, v);
        if (!success) break;
    }

    std::vector<int> values2{0, 1, -1, 42, std::numeric_limits<int>::min(), std::numeric_limits<int>::max()};
    for (auto v : values2) {
        success = test_int_to_float(top, v);
        if (!success) break;
    }

    top->final();

    delete top;

    if (success) std::cout << "Success!\n";

    return success ? 0 : 1;
}