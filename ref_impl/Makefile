# Makefile
# vim: set noet ts=8 sw=8

LDFLAGS		:= $(shell sdl2-config --libs) -lm
SDL_CFLAGS	:= $(shell sdl2-config --cflags)

#CFLAGS		:= -Os -std=c99 -Wall -Wextra -Werror $(SDL_CFLAGS)
#CFLAGS		:= -Os -std=c99 $(SDL_CFLAGS) -I../common
CFLAGS		:= -g -std=c99 $(SDL_CFLAGS) -I../common -DFIXED_POINT=1 -DRASTERIZER_FIXED_POINT=1

SRC := graphite_ref_impl.c sw_rasterizer_standard.c sw_rasterizer_barycentric.c sw_fragment_shader.c ../common/graphite.c ../common/cube.c ../common/teapot.c ../common/tex32x32.c ../common/tex32x64.c ../common/tex256x2048.c

all: graphite_ref_impl

graphite_ref_impl: Makefile $(SRC) ../common/graphite.h ../common/cube.h ../common/teapot.h 
	$(CC) $(CFLAGS) $(SRC) -o graphite_ref_impl $(LDFLAGS) 

clean:
	rm -f graphite_ref_impl

run: graphite_ref_impl
	./graphite_ref_impl

.PHONY: all clean
