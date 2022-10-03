# Makefile
# vim: set noet ts=8 sw=8

LDFLAGS		:= $(shell sdl2-config --libs) -lm
SDL_CFLAGS	:= $(shell sdl2-config --cflags)

#CFLAGS		:= -Os -std=c99 -Wall -Wextra -Werror $(SDL_CFLAGS)
#CFLAGS		:= -Os -std=c99 $(SDL_CFLAGS) -I../common
CFLAGS		:= -g -std=c99 $(SDL_CFLAGS) -I../common -DFIXED_POINT=1

SRC :=

all: graphite_ref_impl

graphite_ref_impl: Makefile graphite_ref_impl.c sw_rasterizer_2.c ../common/graphite.h ../common/cube.h ../common/teapot.h ../common/graphite.c ../common/cube.c ../common/teapot.c
	$(CC) $(CFLAGS) graphite_ref_impl.c sw_rasterizer_2.c ../common/graphite.c ../common/cube.c ../common/teapot.c -o graphite_ref_impl $(LDFLAGS) 

clean:
	rm -f graphite_ref_impl

run: graphite_ref_impl
	./graphite_ref_impl

.PHONY: all clean
