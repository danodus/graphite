# Makefile
# vim: set noet ts=8 sw=8

LDFLAGS		:= $(shell pkg-config sdl2 --libs) -lm
SDL_CFLAGS	:= $(shell pkg-config sdl2 --cflags)

#CFLAGS		:= -Os -std=c99 -Wall -Wextra -Werror $(SDL_CFLAGS)
#CFLAGS		:= -Os -std=c99 $(SDL_CFLAGS) -I../src
CFLAGS		:= -g -std=c99 $(SDL_CFLAGS) -I../src -DFIXED_POINT=1 -DRASTERIZER_FIXED_POINT=1

SRC :=

all: graphite_ref_impl

graphite_ref_impl: Makefile graphite_ref_impl.c sw_rasterizer_standard.c sw_rasterizer_barycentric.c sw_fragment_shader.c ../src/fx.h ../src/glide.h ../src/draw.h ../src/cube.h ../src/teapot.h ../src/glide.c ../src/draw.c ../src/cube.c ../src/teapot.c
	$(CC) $(CFLAGS) graphite_ref_impl.c sw_rasterizer_standard.c sw_rasterizer_barycentric.c sw_fragment_shader.c ../src/glide.c ../src/draw.c ../src/cube.c ../src/teapot.c -o graphite_ref_impl $(LDFLAGS) 

clean:
	rm -f graphite_ref_impl

run: graphite_ref_impl
	./graphite_ref_impl

.PHONY: all clean
