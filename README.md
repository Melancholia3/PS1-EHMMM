
# PS1 Exception Handler by Melancholia3_ -- PS1 Ehmmm

EHMMM (Or EHM3) is an open source bare-metal implementation of a exception handler written on assembly, as such, this should work without any SDK runtime functions

Designed to be portable, lightweight and works without any calls to high level functions like 'printf'


Currently, this handler have the following characteristics

* Works without any sdk, only depending on low level functions
* Doesn't allocate additional buffers or install interrupt handlers
* Sends the register dump by utilizing  the serial port (SIO) using ~115200 bauds, so it can be used on retail consoles
* Captures many of the registers of the ps1, EPC and Cause registers


## Installation

### Using the .s files

1. Put the files exception_handler.s, data.s, hook.s, sio_low.s and the ExceptionHandler.c/.h on your proyect folder
2. Call the hook function from [main()] or any point after the program entry - the BIOS should complete its initialization before jumping to your executable
3. If using GPREL addressing (as psn00bsdk does),Ensure the symbol _gp is on your linker script
4. Enjoy :3

### Using the .o

1. Add the .o files to your CMakeLists or Makefile as additional sources, or link them explicitly with -l
2. Call the hook using the ExceptionHandler.h
3. Ensure your Makefile references the .o files
4. Enjoy :3

## Logging the exception; Requirements

#### For emulators 
* You will need a TTY Client of your preference and configure your emulator to enable TTY console, this will show on the tty client the exception 
#### For console
* You will need to connect your ps1 to your PC with a serial conversor, this should let you see the logs of the exception handler (and your own if implemented) on a serial monitor 

#### Console exclusive Third-Party Tutorials
Use them at your own discretion, The author is not responsible for any hardware damage resulting from these guides
* [Info on Custom DIY Cable](https://lemmings.info/psx-serial-transfer/)
* [More info on a Custom  DIY Cable](https://hitmen.c02.at/html/psx_siocable.html) 
* [Info on PSOne DIY Serial Usb port](https://psx0.wordpress.com/2013/01/22/psone-usb-link-serial/) 

## How does it work?

The low level hook reads and prepares the pointers and memory for the handler and verifier, so, when some of the 16 possible exception codes occurs on your program, the handler will dump the register values saved in cop0 and Thread Control Block directly via SIO

## Known Issues / Bugs

* If a crash ocurrs thorugh memory corruption wiyhout generating a CPU exception (i.e corrupting DMA or GPU state) the handler won't even be triggered and the verifier can get stuck comparing the CAUSE directly from cpu

* No more bugs are currently known, feel free to report!


## Credits

* Martin Korth —  [no\$psx](https://problemkaputt.de/psxspx-index.htm), Layout documentation of INT_RP, TCB and ExcCodes on no$psx

* Spencer Alves  -- [error.c](https://gist.github.com/impiaaa/2c97419435cad2f40fe8a495d696ec52), C implementation of a Error Handler, presented a structure and registers to call

* "Dr.Hell" -- [XEBRA EMULATOR](https://drhell.web.fc2.com/ps1/), Hardware research on PS1 memory map and I/O registers 

* dbousamra -- [Implementation of a Playstation emulator from scratch](https://gist.github.com/dbousamra/f662f381d33fcf5c4a5475c4a656fa19), On direct information of how 0x1F802041 Register is treated in memory and the uses

* PCSX-Redux team -- [Nugget/Openbios](https://github.com/pcsx-redux/nugget/tree/main/openbios), On the saving of TCB in [vectors.s](https://github.com/pcsx-redux/nugget/blob/main/openbios/kernel/vectors.s)