import struct
import serial
import serial.tools.list_ports
import numpy as np
import argparse
import time

try:
    from gpiozero import DigitalOutputDevice
except:
    pass


class STM32Programmer:
    # Constants
    MAX_MEMORY_SIZE = 256
    ## Basic
    START = b"\x7F"
    ACK = b"\x79"
    NACK = b"\0x1F"
    ## Commands
    GET_ID = 0x02
    WRITE_UNPROTECT = 0x73
    WRITE_MEMORY = 0x31
    GO = 0x21
    ERASE = 0x43
    EXTENDED_ERASE = 0x44

    def __init__(self, serial_args, pins, **device_args):
        self.__flash_size = device_args["flash_size"]
        self.__program_start_address = device_args["start_address"]
        self.__ser = serial.Serial(**serial_args)
        self.__ser.timeout = 0.1
        self._start_bootloader(pins)
        if not self.__enter_bootloader():
            raise RuntimeError("Unable to enter bootloader")
        pid = self._get_pid()
        if pid:
            if pid != device_args["pid"]:
                raise RuntimeError(
                    "Received incorrect product ID. Expected %d, got %d"
                    % (args["pid"], pid)
                )
        else:
            raise RuntimeError("Unable to get ID")

    @staticmethod
    def __crc(bytes, start_crc: int = 0):
        crc = start_crc
        for b in bytes:
            crc = crc ^ b
        return crc.to_bytes(1)

    def __get_ack(self):
        ack_byte = self.__ser.read(1)
        return ack_byte == STM32Programmer.ACK

    def __enter_bootloader(self):
        self.__ser.write(STM32Programmer.START)
        return self.__get_ack()

    def __write_command(self, command: int):
        inverse = ~np.uint8(command)
        self.__ser.write(bytes([command, inverse]))
        return self.__get_ack()

    def __write_with_crc(self, bytes):
        crc = STM32Programmer.__crc(bytes)
        self.__ser.write(bytes)
        self.__ser.write(crc)
        return self.__get_ack()

    def __write_memory(self, start_address: int, data: bytes):
        data_len = len(data)
        if data_len > STM32Programmer.MAX_MEMORY_SIZE:
            # Write first 256 bytes
            if self.__write_memory(
                start_address, data[: STM32Programmer.MAX_MEMORY_SIZE]
            ):
                # Write rest at next 256 address
                return self.__write_memory(
                    start_address + STM32Programmer.MAX_MEMORY_SIZE,
                    data[STM32Programmer.MAX_MEMORY_SIZE :],
                )
        else:
            if self.__write_command(STM32Programmer.WRITE_MEMORY):
                if self.__write_with_crc(start_address.to_bytes(4)):
                    return self.__write_with_crc(bytes([data_len - 1]) + data)
        return False

    def __erase_memory(self):
        # self.__write_unprotect()
        if self.__write_command(STM32Programmer.ERASE):
            self.__ser.write(bytes([0xFF, 0x00]))
            return self.__get_ack()
        else:
            return self.__extended_erase_memory()

    def __extended_erase_memory(self):
        if self.__write_command(STM32Programmer.EXTENDED_ERASE):
            self.__ser.timeout = None
            res = self.__write_with_crc(bytes([0xFF, 0xFF]))
            self.__ser.timeout = 0.1
            return res

    def __write_unprotect(self):
        if self.__write_command(STM32Programmer.WRITE_UNPROTECT):
            return self.__get_ack()
        return False

    def _start_bootloader(self, pins):
        # Set boot pins
        if pins["bt0"] is not None:
            pins["bt0"].on()
        if pins["bt1"] is not None:
            pins["bt1"].off()
        time.sleep(0.1)  # Wait 100ms

        # Reset
        if pins["rst"] is not None:
            pins["rst"].off()
            time.sleep(0.5)  # Wait 500ms
            pins["rst"].on()
            time.sleep(0.5)  # Wait another 500ms before reset boot

        # Reset boot pins
        if pins["bt0"] is not None:
            pins["bt0"].off()
            del pins["bt0"]
        if pins["bt1"] is not None:
            pins["bt1"].on()
            del pins["bt1"]

    def __get_id(self):
        if self.__write_command(STM32Programmer.GET_ID):
            num_byte = int.from_bytes(self.__ser.read()) + 1
            id_bytes = self.__ser.read(num_byte)
            if self.__get_ack():
                return int.from_bytes(id_bytes)
        return None

    def _get_pid(self):
        return self.__get_id()

    def write_image(self, file_name):
        with open(file_name, "rb") as file:
            data = file.read()

        if len(data) < self.__flash_size:
            if self.__erase_memory():
                return self.__write_memory(self.__program_start_address, data)
            else:
                raise RuntimeError("Unable to erase")
        else:
            raise RuntimeError("File too big")

    def go(self):
        if self.__write_command(STM32Programmer.GO):
            return self.__write_with_crc(self.__program_start_address.to_bytes(4))


class BNRGLPProgrammer(STM32Programmer):
    def _get_pid(self):
        id = super()._get_pid()
        return id & 0xFF


SUPPORTED_DEVICES = {
    "BlueNRG-LP": {
        "class": BNRGLPProgrammer,
        "device_args": {
            "flash_size": 256000,
            "start_address": 0x10040000,
            "pid": 0x3F,
        },
    },
    "BlueNRG-LPS": {
        "class": BNRGLPProgrammer,
        "device_args": {
            "flash_size": 192000,
            "start_address": 0x10040000,
            "pid": 0x3B,
        },
    },
    "STM32F411xx": {
        "class": STM32Programmer,
        "serial_args": {"parity": serial.PARITY_EVEN},
    },
    "STM32F411xE": {
        "class": STM32Programmer,
        "serial_args": {"parity": serial.PARITY_EVEN},
        "device_args": {
            "flash_size": 512000,
            "start_address": 0x08000000,
            "pid": 0x431,
        },
    },
}

if __name__ == "__main__":

    def parse_prog_args(args):
        serial_args = {
            "port": args.serial_port,
            "baudrate": args.serial_baud,
        }

        def pin_init(pin: int, init_val):
            if pin is not None:
                try:
                    return DigitalOutputDevice(pin, initial_value=init_val)
                except:
                    pass
            return None

        pins = {
            "rst": pin_init(args.reset, True),
            "bt0": pin_init(args.boot0, False),
            "bt1": pin_init(args.boot1, True),
        }
        return (serial_args, pins)

    for programmer_class in STM32Programmer.__subclasses__():
        SUPPORTED_DEVICES[programmer_class.__name__] = {"class": programmer_class}

    # Adapted from https://www.geeksforgeeks.org/python-key-value-pair-using-argparse/
    # create a keyvalue class
    class keyvalue(argparse.Action):
        # Constructor calling
        def __call__(self, parser, namespace, values, option_string=None):
            setattr(namespace, self.dest, dict())

            for value in values:
                # split it into key and value
                key, value = value.split("=")
                # assign into dictionary
                getattr(namespace, self.dest)[key] = value

    parser = argparse.ArgumentParser()
    # Device options
    device_parser = parser.add_argument_group(
        "Device", "Options for selecting device and binary file"
    )
    device_parser.add_argument(
        "-d", "--device", type=str, required=True, help="Device or programmer to use"
    )
    device_parser.add_argument(
        "-b", "--binary", type=str, required=True, help="Binary (*.bin) firmware file"
    )
    device_parser.add_argument(
        "-dargs",
        "--device-args",
        nargs="*",
        action=keyvalue,
        default={},
        help="Additional device options in k0=v0 ... kn=vn format",
    )
    # Serial options
    default_port = sorted(serial.tools.list_ports.comports())[0].device
    serial_parser = parser.add_argument_group("Serial", "Options for serial port")
    serial_parser.add_argument(
        "-spt",
        "--serial_port",
        type=str,
        default=default_port,
        help="Serial port connected to the STM32",
    )
    serial_parser.add_argument(
        "-sbd", "--serial_baud", type=int, default=115200, help="Serial port baud rate"
    )
    # Pin options
    pin_parser = parser.add_argument_group(
        "Pins", "Options for connecting to hardware pins"
    )
    pin_parser.add_argument(
        "-rst", "--reset", type=int, help="Pin connected to nRST pin of the STM32"
    )
    pin_parser.add_argument(
        "-bt0", "--boot0", type=int, help="Pin connected to BOOT0 pin of the STM32"
    )
    pin_parser.add_argument(
        "-bt1", "--boot1", type=int, help="Pin connected to BOOT1 pin of the STM32"
    )

    # Parse args
    args = parser.parse_args()
    serial_args, pins = parse_prog_args(args)
    device_args = args.device_args

    try:
        device_options = SUPPORTED_DEVICES[args.device]
    except KeyError:
        raise RuntimeError(
            "Unsupported device or programmer. Supported devices and programmers are: \n\r%s"
            % list(SUPPORTED_DEVICES.keys())
        )
    programmer_class = device_options["class"]
    # Add default serial options
    try:
        serial_args = {**device_options["serial_args"], **serial_args}
    except KeyError:
        pass
    # Add default device arguments
    try:
        device_args = {**device_options["device_args"], **device_args}
    except KeyError:
        pass

    programmer = programmer_class(serial_args, pins, **device_args)
    if programmer.write_image(args.binary):
        print(programmer.go())
    else:
        print("Failed")
