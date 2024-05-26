PYTHON = python3

RISCV_TOOLCHAIN_PATH =
RISCV_TOOLCHAIN_PREFIX = riscv-none-elf-

AS = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}as
OBJCOPY = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}objcopy
OBJDUMP = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}objdump
CC = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}gcc
CXX = ${RISCV_TOOLCHAIN_PATH}${RISCV_TOOLCHAIN_PREFIX}g++

SERIAL ?= /dev/tty.usbserial-D00039

TARGET_EXEC := program.elf

BUILD_DIR := ./build
SRC_DIRS := ./src

CXXFLAGS := -I../lib

# Find all the C and C++ files we want to compile
# Note the single quotes around the * expressions. The shell will incorrectly expand these otherwise, but we want to send the * directly to the find command.
SRCS := ./src/start.S
SRCS += $(shell find $(SRC_DIRS) -name '*.c' -or -name '*.cpp')

# Prepends BUILD_DIR and appends .o to every src file
# As an example, ./your_dir/hello.cpp turns into ./build/./your_dir/hello.cpp.o
OBJS := $(SRCS:%=$(BUILD_DIR)/%.o)

# String substitution (suffix version without %).
# As an example, ./build/hello.cpp.o turns into ./build/hello.cpp.d
DEPS := $(OBJS:.o=.d)

# Every folder in ./src will need to be passed to GCC so that it can find header files
INC_DIRS := $(shell find $(SRC_DIRS) -type d)
# Add a prefix to INC_DIRS. So moduleA would become -ImoduleA. GCC understands this -I flag
INC_FLAGS := $(addprefix -I,$(INC_DIRS))

# The -MMD and -MP flags together generate Makefiles for us!
# These files will have .d instead of .o as the output.
CPPFLAGS := $(INC_FLAGS) -MMD -MP -g

all: $(BUILD_DIR)/program.hex

# The final build step.
$(BUILD_DIR)/$(TARGET_EXEC): $(OBJS)
	$(CXX) -march=rv32i -mabi=ilp32 -nostartfiles -T program.ld $(OBJS) -o $@ $(LDFLAGS) -lm -lstdc++

# Build step for S source
$(BUILD_DIR)/%.S.o: %.S
	mkdir -p $(dir $@)
	$(CC) -march=rv32i -mabi=ilp32 $(CPPFLAGS) $(CFLAGS) -c $< -o $@

# Build step for C source
$(BUILD_DIR)/%.c.o: %.c
	mkdir -p $(dir $@)
	$(CC) -march=rv32i -mabi=ilp32 $(CPPFLAGS) $(CFLAGS) -c $< -o $@

# Build step for C++ source
$(BUILD_DIR)/%.cpp.o: %.cpp
	mkdir -p $(dir $@)
	$(CXX) -march=rv32i -mabi=ilp32 -std=c++17 $(CPPFLAGS) $(CXXFLAGS) -c $< -o $@

$(BUILD_DIR)/program.lst: $(BUILD_DIR)/program.elf
	${OBJDUMP} --disassemble --source $(BUILD_DIR)/program.elf > $(BUILD_DIR)/program.lst

$(BUILD_DIR)/program.hex: $(BUILD_DIR)/program.bin
	${PYTHON} ../../../../utils/makehex.py $(BUILD_DIR)/program.bin > $(BUILD_DIR)/program.hex

$(BUILD_DIR)/program.bin: $(BUILD_DIR)/program.elf $(BUILD_DIR)/program.lst
	${OBJCOPY} -O binary $(BUILD_DIR)/program.elf $(BUILD_DIR)/program.bin

run: $(BUILD_DIR)/program.hex
	$(PYTHON) ../../../../utils/sendhex.py $(SERIAL) $(BUILD_DIR)/program.hex

.PHONY: all clean
clean:
	rm -r $(BUILD_DIR)

# Include the .d makefiles. The - at the front suppresses the errors of missing
# Makefiles. Initially, all the .d files will be missing, and we don't want those
# errors to show up.
-include $(DEPS)























