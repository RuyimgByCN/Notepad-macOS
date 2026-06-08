#ifndef LexillaBridge_h
#define LexillaBridge_h

#ifdef __cplusplus
extern "C" {
#endif

/// Load a lexer by name. Returns a pointer to the ILexer5 instance or NULL.
/// This wraps the Lexilla CreateLexer function.
void* LexillaBridge_CreateLexer(const char* name);

#ifdef __cplusplus
}
#endif

#endif /* LexillaBridge_h */
