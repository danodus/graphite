import os
import sys

vertices = []
texcoords = []
faces = []


def puts(s):
    print(s, end='')


def process_line(line):
    global vertices, texcoords, faces
    words = line.split()
    if words[0] == "v":
        vertices.append([float(words[1]), float(words[2]), float(words[3])])
    elif words[0] == "vt":
        texcoords.append([float(words[1]), float(words[2])])
    elif words[0] == "f":
        w1 = words[1].split('/')
        w2 = words[2].split('/')
        w3 = words[3].split('/')
        faces.append([int(w1[0])-1, int(w2[0])-1, int(w3[0])-1,
                     int(w1[1])-1, int(w2[1])-1, int(w3[1])-1])


def print_vertices(array):
    puts("static vec3d vertices[] = {\n")
    for i, v in enumerate(array):
        puts("{{FX({}f), FX({}f), FX({}f), FX(1.0f)}}".format(
            v[0], v[1], v[2]))
        if (i < len(array) - 1):
            puts(",")
        puts("\n")
    puts("};\n")


def print_texcoords(array):
    puts("static vec2d texcoords[] = {\n")
    for i, v in enumerate(array):
        puts("{{FX({}f), FX({}f)}}".format(v[0], v[1]))
        if (i < len(array) - 1):
            puts(",")
        puts("\n")
    puts("};\n")


def print_faces(array):
    puts("static face_t faces[] = {\n")
    for i, v in enumerate(array):
        puts("{{{}, {}, {}}}, {{FX(1.0f), FX(1.0f), FX(1.0f), FX(1.0f)}}, {{{}, {}, {}}}}}".format(
            v[0], v[1], v[2], v[3], v[4], v[5]))
        if (i < len(array) - 1):
            puts(",")
        puts("\n")
    puts("};\n")


def print_all():
    print_vertices(vertices)
    print_texcoords(texcoords)
    print_faces(faces)


def main(argv):
    if (len(argv) == 0):
        print("Usage: obj2c.rb <objfile>")
        exit(0)
    else:
        if (not os.path.exists(argv[0])):
            print("{} does not exist".format(argv[0]))
            exit(-1)

        f = open(argv[0], 'r')
        lines = f.readlines()

        for line in lines:
            process_line(line)

        print_all()
    exit(0)


if __name__ == "__main__":
    main(sys.argv[1:])
