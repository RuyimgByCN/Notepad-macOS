#!/usr/bin/env python3
"""Apply Scintilla cocoa patches for macOS 26+ compatibility."""
import re
import sys

# The complete patch code to insert after the SCIContentView drawRect marker.
#
# macOS 26+ forces layer-backed rendering on all NSViews. For content
# views inside NSScrollView, AppKit defaults to calling updateLayer:
# (which only sets layer properties like backgroundColor) instead of
# drawRect:. This leaves the editor blank because SCIContentView draws
# custom text content via drawRect:, not just layer properties.
#
# Override wantsUpdateLayer to return NO — this tells AppKit NOT to use
# updateLayer:, and instead fall back to the default displayLayer:
# implementation, which calls drawRect: under the hood. This preserves
# Scintilla's original incremental dirty-rect painting: drawRect: receives
# the dirty rect, so only the changed region is redrawn.
#
# NOTE: an earlier version of this patch implemented displayLayer: directly
# and called Draw(bounds), redrawing the entire visible region on every
# frame. That pinned the main thread at ~80% CPU and made the app appear
# hung when loading files with many lines (e.g. a 5k-line log), because
# every caret blink / styling tick triggered a full
# DrawLine -> FillLineRemainder -> CGContextFillRect pass over the whole
# viewport. Relying on drawRect:'s dirty rect avoids that.
PATCH_CODE = '''

//--------------------------------------------------------------------------------------------------

// macOS 26+ forces layer-backed rendering on all NSViews. For content
// views inside NSScrollView, AppKit defaults to calling updateLayer:
// (which only sets layer properties like backgroundColor) instead of
// drawRect:. This leaves the editor blank because SCIContentView draws
// custom text content via drawRect:, not just layer properties.
//
// Override wantsUpdateLayer to return NO — this tells AppKit NOT to use
// updateLayer:, and instead fall back to the default displayLayer:
// implementation, which calls drawRect: under the hood. This preserves
// Scintilla's original incremental dirty-rect painting: drawRect: receives
// the dirty rect, so only the changed region is redrawn.

+ (BOOL) wantsUpdateLayer {
	return NO;  // Force AppKit to use drawRect: for content drawing
}'''

# The drawRect closing block we use as an insertion marker.
# Compiled as a regex so the match tolerates arbitrary leading whitespace per
# line: upstream has reshuffled SCIContentView.drawRect's indentation between
# commits (pinned 6ab5c211 vs newer eb17eab differ by a full indent level),
# which broke the previous literal-text marker. The non-whitespace structure
# below is stable.
MARKER_RE = re.compile(
    r'[ \t]*if \(!mOwner\.backend->Draw\(rect, context\)\) \{\n'
    r'[ \t]*dispatch_async\(dispatch_get_main_queue\(\), \^ \{\n'
    r'[ \t]*\[self setNeedsDisplay: YES\];\n'
    r'[ \t]*\}\);\n'
    r'[ \t]*\}\n'
    r'[ \t]*\}'
)


def is_patch_already_applied(content):
    """Check whether the current (drawRect-based) patch is already applied:
    the wantsUpdateLayer override is present AND no displayLayer: override
    remains (the old patch added one and it caused full-viewport redraws)."""
    return '+ (BOOL) wantsUpdateLayer' in content and '- (void) displayLayer:' not in content


def remove_old_patch(content):
    """Remove any existing wantsUpdateLayer/displayLayer implementations.

    Used to migrate from the old displayLayer:-based patch (which redrew the
    whole viewport every frame) to the new drawRect-based patch. Uses a
    line-by-line approach: find the start of the patch block
    (the separator line before wantsUpdateLayer) and the end of
    displayLayer's closing brace, then remove everything between them.
    """
    lines = content.split('\n')
    remove_start = None  # first line to remove
    remove_end = None    # last line to remove (exclusive)

    # Find the patch separator: look for '//--------------------------------------------------------------------------------------------------'
    # that appears right before a line containing 'wantsUpdateLayer'
    for i, line in enumerate(lines):
        if '+ (BOOL) wantsUpdateLayer' in line:
            # Walk backwards to find the separator line
            for j in range(i - 1, -1, -1):
                stripped = lines[j].strip()
                if stripped == '//--------------------------------------------------------------------------------------------------':
                    remove_start = j
                    break
                elif stripped == '' or stripped.startswith('//'):
                    continue  # skip blank lines and comments
                else:
                    remove_start = i  # no separator found; start at method
                    break
            break

    if remove_start is None:
        return content  # nothing to remove

    # Find the closing brace of displayLayer: method
    brace_depth = 0
    found_display_layer = False
    for i, line in enumerate(lines):
        if '- (void) displayLayer:' in line:
            found_display_layer = True
        if found_display_layer:
            brace_depth += line.count('{') - line.count('}')
            if brace_depth <= 0 and '{' in ''.join(lines[remove_start:i+1]):
                remove_end = i + 1
                break

    # Also remove trailing blank lines after the method
    if remove_end is not None:
        while remove_end < len(lines) and lines[remove_end].strip() == '':
            remove_end += 1

    if remove_start is not None and remove_end is not None:
        new_lines = lines[:remove_start] + lines[remove_end:]
        print(f"  Removed old patch implementation (lines {remove_start+1}-{remove_end})")
        return '\n'.join(new_lines)

    return content  # couldn't find removal boundaries


def apply_display_layer_patch(filepath):
    """Add wantsUpdateLayer=NO to SCIContentView for macOS 26+.

    macOS 26 forces layer-backed rendering on all NSViews. For content views
    inside NSScrollView, AppKit calls updateLayer: (NOT drawRect:) because
    NSView.wantsUpdateLayer defaults to YES in layer-backed mode. updateLayer:
    only sets layer properties (background color, etc.) and does NOT draw
    custom content — which explains why the editor renders as blank white.

    Fix: override wantsUpdateLayer to return NO, forcing AppKit to fall back
    to the default displayLayer: implementation, which calls drawRect:. This
    preserves Scintilla's incremental dirty-rect painting instead of redrawing
    the whole viewport every frame.
    """
    with open(filepath, 'r') as f:
        content = f.read()

    # Fast path: patch already correctly applied → skip entirely
    if is_patch_already_applied(content):
        print(f"  Patch already applied correctly in {filepath}")
        return True

    # Slow path: old/incorrect implementation exists → remove it first
    if '+ (BOOL) wantsUpdateLayer' in content or '- (void) displayLayer:' in content:
        print(f"  Found old implementation, removing before re-apply...")
        content = remove_old_patch(content)
        # Write the cleaned content so we can re-apply fresh
        with open(filepath, 'w') as f:
            f.write(content)
        # Re-read to ensure consistent state
        with open(filepath, 'r') as f:
            content = f.read()

    # Find the SCIContentView drawRect marker. The marker text
    # (mOwner.backend->Draw + setNeedsDisplay: YES) only appears in
    # SCIContentView, not SCIMarginView, so the match is normally unique;
    # if more than one matches, prefer the last (the deeper class).
    matches = list(MARKER_RE.finditer(content))
    if not matches:
        print(f"  ERROR: Could not find marker in {filepath}")
        return False
    match = matches[-1]

    # Insert patch code after the marker
    insert_pos = match.end()
    content = content[:insert_pos] + PATCH_CODE + content[insert_pos:]

    with open(filepath, 'w') as f:
        f.write(content)

    print(f"  Applied: wantsUpdateLayer=NO (drawRect-based) patch to {filepath}")
    return True


if __name__ == '__main__':
    scintilla_view = sys.argv[1] if len(sys.argv) > 1 else 'upstream/notepad-plus-plus/scintilla/cocoa/ScintillaView.mm'
    success = apply_display_layer_patch(scintilla_view)
    sys.exit(0 if success else 1)
