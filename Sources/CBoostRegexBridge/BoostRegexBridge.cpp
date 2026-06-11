// C ABI wrapper around the upstream-vendored Boost.Regex (boostregex/boost),
// mirroring the flags Notepad++ uses in BoostRegExSearch.cxx:
//   compile: regex_constants::ECMAScript | (caseSensitive ? 0 : icase)
//   search:  match_default | (dotMatchesNewline ? 0 : match_not_dot_newline)
//   format:  boost::format_all
//
// macOS wchar_t is 4 bytes, so the bridge works in UTF-32 code points and
// the Swift side converts to/from UTF-16 offsets.

#include "include/BoostRegexBridge.h"

#include <boost/regex.hpp>

#include <cstring>
#include <new>
#include <string>

static_assert(sizeof(wchar_t) == 4, "bridge assumes UTF-32 wchar_t");

namespace {

using WRegex = boost::basic_regex<wchar_t>;
using WMatch = boost::match_results<const wchar_t *>;

std::wstring toWide(const uint32_t *units, long length) {
    std::wstring result;
    if (length > 0) {
        result.reserve(static_cast<size_t>(length));
        for (long i = 0; i < length; ++i) {
            result.push_back(static_cast<wchar_t>(units[i]));
        }
    }
    return result;
}

void copyError(const char *message, char *errorBuf, long capacity) {
    if (errorBuf == nullptr || capacity <= 0) return;
    long length = static_cast<long>(std::strlen(message));
    if (length >= capacity) length = capacity - 1;
    std::memcpy(errorBuf, message, static_cast<size_t>(length));
    errorBuf[length] = '\0';
}

}  // namespace

struct NPBoostRegexHandle {
    WRegex regex;
    // The searched text is copied so the retained match_results iterators
    // stay valid until the next search on this handle.
    std::wstring lastText;
    WMatch lastMatch;
    bool hasMatch = false;
};

extern "C" {

NPBoostRegexHandle *npboost_regex_create(
    const uint32_t *pattern,
    long patternLength,
    int caseSensitive,
    char *errorBuf,
    long errorBufCapacity) {
    if (pattern == nullptr && patternLength > 0) {
        copyError("null pattern", errorBuf, errorBufCapacity);
        return nullptr;
    }
    auto *handle = new (std::nothrow) NPBoostRegexHandle();
    if (handle == nullptr) {
        copyError("out of memory", errorBuf, errorBufCapacity);
        return nullptr;
    }
    try {
        boost::regex_constants::syntax_option_type flags =
            boost::regex_constants::ECMAScript;
        if (caseSensitive == 0) {
            flags |= boost::regex_constants::icase;
        }
        handle->regex.assign(toWide(pattern, patternLength), flags);
        return handle;
    } catch (const boost::regex_error &error) {
        copyError(error.what(), errorBuf, errorBufCapacity);
    } catch (const std::exception &error) {
        copyError(error.what(), errorBuf, errorBufCapacity);
    } catch (...) {
        copyError("unknown regex compile error", errorBuf, errorBufCapacity);
    }
    delete handle;
    return nullptr;
}

void npboost_regex_destroy(NPBoostRegexHandle *handle) {
    delete handle;
}

int npboost_regex_group_count(const NPBoostRegexHandle *handle) {
    if (handle == nullptr) return 0;
    return static_cast<int>(handle->regex.mark_count());
}

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
    long *groupCount) {
    if (handle == nullptr || (text == nullptr && textLength > 0)) return -1;
    if (textLength < 0 || startPos < 0 || endPos < 0) return -1;
    if (startPos > textLength) startPos = textLength;
    if (endPos > textLength) endPos = textLength;
    if (startPos > endPos) return 0;

    try {
        handle->lastText = toWide(text, textLength);
        handle->hasMatch = false;

        const wchar_t *base = handle->lastText.data();
        const wchar_t *first = base + startPos;
        const wchar_t *last = base + endPos;

        boost::regex_constants::match_flag_type flags =
            boost::regex_constants::match_default;
        if (matchNotDotNewline != 0) {
            flags |= boost::regex_constants::match_not_dot_newline;
        }
        // Like upstream: when the window does not start at the buffer
        // beginning, let ^ / \b consult the preceding character.
        if (startPos > 0) {
            flags |= boost::regex_constants::match_prev_avail;
        }

        WMatch match;
        if (!boost::regex_search(first, last, match, handle->regex, flags)) {
            return 0;
        }

        handle->lastMatch = match;
        handle->hasMatch = true;

        const long available = static_cast<long>(match.size());
        if (groupCount != nullptr) *groupCount = available;
        if (groupBegins != nullptr && groupEnds != nullptr) {
            const long reported = available < groupCapacity ? available : groupCapacity;
            for (long i = 0; i < reported; ++i) {
                const auto &group = match[static_cast<int>(i)];
                if (group.matched) {
                    groupBegins[i] = static_cast<long>(group.first - base);
                    groupEnds[i] = static_cast<long>(group.second - base);
                } else {
                    groupBegins[i] = NPBOOST_NO_GROUP;
                    groupEnds[i] = NPBOOST_NO_GROUP;
                }
            }
        }
        return 1;
    } catch (...) {
        handle->hasMatch = false;
        return -1;
    }
}

long npboost_regex_format(
    NPBoostRegexHandle *handle,
    const uint32_t *replacement,
    long replacementLength,
    uint32_t *out,
    long outCapacity) {
    if (handle == nullptr || !handle->hasMatch) return -1;
    if (replacement == nullptr && replacementLength > 0) return -1;
    try {
        const std::wstring formatted = handle->lastMatch.format(
            toWide(replacement, replacementLength), boost::format_all);
        const long total = static_cast<long>(formatted.size());
        if (out != nullptr && outCapacity > 0) {
            const long copied = total < outCapacity ? total : outCapacity;
            for (long i = 0; i < copied; ++i) {
                out[i] = static_cast<uint32_t>(formatted[static_cast<size_t>(i)]);
            }
        }
        return total;
    } catch (...) {
        return -1;
    }
}

}  // extern "C"
