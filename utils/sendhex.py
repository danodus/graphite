import sys
import serial
import time

delay_word = 0
delay_block = 0

def send(ser, bytes, delay):
    ser.write(bytes)
    time.sleep(delay)

def main(argv):
    if (len(argv) < 2):
        print("Usage: sendhex.py <serial device> <hex file> [delay per word in s] [delay per block in s]")
        exit(0)
    else:
        if (len(argv) >= 3):
            global delay_word
            delay_word = float(argv[2])

        if (len(argv) >= 4):
            global delay_block
            delay_block = float(argv[3])

        try:
            ser = serial.Serial(argv[0], baudrate=115200)
        except serial.serialutil.SerialException:
            print("Unable to open the serial device {0}".format(argv[0]))
            exit(1)
        file = open(argv[1], 'r')
        lines = file.read().splitlines()
        lines = list(filter(None, lines))   # remove empty lines

        length = len(lines)
        send(ser, length.to_bytes(4, 'big'), delay_block)

        cnt = 0
        for line in lines:
            if (line == '0'):
                line = '00000000'
            d = delay_word
            if (cnt > 0) and ((cnt + 4) % 512 == 0):
                d = delay_block
            send(ser, bytearray.fromhex(line), d)
            cnt = cnt + 4
        time.sleep(2)
        ser.close()
    exit(0)


if __name__ == "__main__":
    main(sys.argv[1:])
