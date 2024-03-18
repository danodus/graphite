
import sys
import os
from PIL import Image

if len(sys.argv) != 3:
    print('Usage: python {} image.png array.c'.format(sys.argv[0]))
    sys.exit(1)

im = Image.open(sys.argv[1])

with open(sys.argv[2], 'w') as f:
    while True:
        rgb_im = im.convert('RGBA')
        size = rgb_im.size

        array = []
        for y in range(size[1]):
            for x in range(size[0]):
                rgba = rgb_im.getpixel((x, y))
                a = rgba[3] >> 4
                r = rgba[0] >> 4
                g = rgba[1] >> 4
                b = rgba[2] >> 4
                array.append(a << 12 | r << 8 | g << 4 | b)

        f.write('#include <stdint.h>\n\n')
        f.write('uint16_t {}[] = {{'.format(os.path.splitext(os.path.basename(sys.argv[1]))[0]))
        f.write(str(array)[1:-1])
        f.write('};\n')

        # To iterate through the entire image
        try:
            im.seek(im.tell()+1)
        except EOFError:
            break  # end of sequence
