# Makefile
# vim: set noet ts=8 sw=8

LDFLAGS		:= $(shell pkg-config sdl2 --libs) -lm
SDL_CFLAGS	:= $(shell pkg-config sdl2 --cflags)

CFLAGS		:= -g -std=c99 $(SDL_CFLAGS) -I.. -I../../src -I../../ref_impl -DGLIDE_SDL=1

COMMON_SRC := ../../ref_impl/sw_rasterizer_standard.c ../../ref_impl/sw_fragment_shader.c ../../src/glide.c tlib.c

all: test0 test1 test2 test3 test4 test5 test20

test0: Makefile ../../src/glide.h $(COMMON_SRC) test0.c
	$(CC) $(CFLAGS) $(COMMON_SRC) test0.c -o test0 $(LDFLAGS) 

test1: Makefile ../../src/glide.h $(COMMON_SRC) test1.c
	$(CC) $(CFLAGS) $(COMMON_SRC) test1.c -o test1 $(LDFLAGS) 

test2: Makefile ../../src/glide.h $(COMMON_SRC) test2.c
	$(CC) $(CFLAGS) $(COMMON_SRC) test2.c -o test2 $(LDFLAGS) 

test3: Makefile ../../src/glide.h $(COMMON_SRC) test3.c
	$(CC) $(CFLAGS) $(COMMON_SRC) test3.c -o test3 $(LDFLAGS) 

test4: Makefile ../../src/glide.h $(COMMON_SRC) test4.c
	$(CC) $(CFLAGS) $(COMMON_SRC) test4.c -o test4 $(LDFLAGS) 

test5: Makefile ../../src/glide.h $(COMMON_SRC) test5.c
	$(CC) $(CFLAGS) $(COMMON_SRC) test5.c -o test5 $(LDFLAGS) 

test20: Makefile ../../src/glide.h $(COMMON_SRC) test20.c
	$(CC) $(CFLAGS) $(COMMON_SRC) test20.c -o test20 $(LDFLAGS) 

clean:
	rm -f test0 test1 test2 test3 test4 test5 test20

.PHONY: all clean
