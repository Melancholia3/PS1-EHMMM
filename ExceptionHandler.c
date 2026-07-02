/* ExceptionHandler.c

This file is only needed to install the exception handler. 
It is not needed for the actual exception handling,
which is done in ExceptionHandler.asm.

You can tweek this, as this is an example to load it


*/


extern void hook(void);
void InstallExceptionHandler(void) {
    hook();
}