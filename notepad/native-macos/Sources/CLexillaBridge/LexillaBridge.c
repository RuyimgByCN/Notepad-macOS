#include "include/LexillaBridge.h"

// Declare the Lexilla function (it's extern "C" in the library)
extern void* CreateLexer(const char* name);

void* LexillaBridge_CreateLexer(const char* name) {
    return CreateLexer(name);
}
