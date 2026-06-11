#ifndef BOOST_REGEX_BRIDGE_H
#define BOOST_REGEX_BRIDGE_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

/// Opaque handle for one compiled Boost regex plus its last match state.
typedef struct NPBoostRegexHandle NPBoostRegexHandle;

/// Sentinel offset for groups that did not participate in the match.
#define NPBOOST_NO_GROUP (-1L)

/// Compiles `pattern` (UTF-32 code points, `patternLength` units) with
/// upstream Notepad++ flags (Perl/ECMAScript syntax, optional icase).
/// Returns NULL on failure and copies a UTF-8 error message into
/// `errorBuf` when provided.
NPBoostRegexHandle *npboost_regex_create(
    const uint32_t *pattern,
    long patternLength,
    int caseSensitive,
    char *errorBuf,
    long errorBufCapacity);

void npboost_regex_destroy(NPBoostRegexHandle *handle);

/// Number of capture groups in the compiled pattern (excluding group 0).
int npboost_regex_group_count(const NPBoostRegexHandle *handle);

/// Searches `text` (UTF-32 code points) inside [startPos, endPos).
/// `matchNotDotNewline` mirrors upstream: non-zero unless the
/// ". matches newline" search option is enabled.
/// Returns 1 on match, 0 on no match, -1 on error.
/// On match fills `groupBegins`/`groupEnds` (UTF-32 offsets into `text`)
/// for up to `groupCapacity` groups including group 0, and stores the
/// total available group count (matched groups + 1) in `groupCount`.
/// Unmatched optional groups report NPBOOST_NO_GROUP for both offsets.
/// The match state is retained on the handle for npboost_regex_format.
int npboost_regex_search(
    NPBoostRegexHandle *handle,
    const uint32_t *text,
    long textLength,
    long startPos,
    long endPos,
    int matchNotDotNewline,
    long *groupBegins,
    long *groupEnds,
    long groupCapacity,
    long *groupCount);

/// Formats `replacement` (UTF-32) against the most recent successful
/// search on this handle using boost::format_all (same as upstream
/// SubstituteByPosition). Returns the full result length in UTF-32
/// units, copying up to `outCapacity` units into `out`. Returns -1 when
/// there is no previous match or formatting fails. Call once with
/// capacity 0 to size the buffer, then again to copy.
long npboost_regex_format(
    NPBoostRegexHandle *handle,
    const uint32_t *replacement,
    long replacementLength,
    uint32_t *out,
    long outCapacity);

#ifdef __cplusplus
}
#endif

#endif /* BOOST_REGEX_BRIDGE_H */
