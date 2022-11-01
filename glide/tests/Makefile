# Makefile
# vim: set noet ts=8 sw=8

LDFLAGS		:= $(shell sdl2-config --libs) -lm
SDL_CFLAGS	:= $(shell sdl2-config --cflags)

CFLAGS		:= -g -std=c99 $(SDL_CFLAGS) -I.. -I../../common -I../../ref_impl

COMMON_SRC := ../../ref_impl/sw_rasterizer_standard.c ../glide.c tlib.c

all: test0 test1 test2 test3

test0: Makefile ../glide.h $(COMMON_SRC) test0.c
	$(CC) $(CFLAGS) $(COMMON_SRC) test0.c -o test0 $(LDFLAGS) 

test1: Makefile ../glide.h $(COMMON_SRC) test1.c
	$(CC) $(CFLAGS) $(COMMON_SRC) test1.c -o test1 $(LDFLAGS) 

test2: Makefile ../glide.h $(COMMON_SRC) test2.c
	$(CC) $(CFLAGS) $(COMMON_SRC) test2.c -o test2 $(LDFLAGS) 

test3: Makefile ../glide.h $(COMMON_SRC) test3.c
	$(CC) $(CFLAGS) $(COMMON_SRC) test3.c -o test3 $(LDFLAGS) 

clean:
	rm -f test0 test1 test2

.PHONY: all clean
