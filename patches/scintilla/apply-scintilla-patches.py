#!/usr/bin/env python3
"""Apply Scintilla cocoa patches for macOS 26+ compatibility."""
import sys

def apply_display_layer_patch(filepath):
    """Add displayLayer: method to SCIContentView for macOS 26+ layer-backed rendering."""
    # The marker is the SCIContentView drawRect implementation
    marker = '''	if (!mOwner.backend->Draw(rect, context)) {
		dispatch_async(dispatch_get_main_queue(), ^ {
			[self setNeedsDisplay: YES];
		});
	}
}'''
    
    # Code to insert AFTER the marker (no duplicate closing brace)
    insert_code = '''

//--------------------------------------------------------------------------------------------------

/**
 * macOS 26+ (Tahoe) forces layer-backed rendering on all NSViews.
 * When layer-backed, AppKit may call displayLayer: instead of drawRect:
 * to render the view's content. SCIContentView only implements drawRect:
 * which relies on CGContextCurrent() that returns NULL outside drawRect's
 * graphics context stack. This method forces the traditional drawRect:
 * path by calling display() which invokes drawRect with proper context.
 */
- (void) displayLayer: (CALayer *) layer {
	[self setNeedsDisplay: YES];
	[self display];
}'''
    
    with open(filepath, 'r') as f:
        content = f.read()
    
    # Only apply once
    if 'displayLayer:' in content:
        print(f"  Patch already applied: displayLayer method exists in {filepath}")
        return True
    
    # Find the second occurrence of the marker (SCIContentView, not SCIMarginView)
    pos = content.find(marker)
    if pos == -1:
        print(f"  ERROR: Could not find marker in {filepath}")
        return False
    
    pos2 = content.find(marker, pos + len(marker))
    if pos2 != -1:
        pos = pos2
    
    # Insert after the closing brace
    insert_pos = pos + len(marker)
    content = content[:insert_pos] + insert_code + content[insert_pos:]
    
    with open(filepath, 'w') as f:
        f.write(content)
    
    print(f"  Applied: displayLayer patch to {filepath}")
    return True

if __name__ == '__main__':
    scintilla_view = sys.argv[1] if len(sys.argv) > 1 else 'upstream/notepad-plus-plus/scintilla/cocoa/ScintillaView.mm'
    success = apply_display_layer_patch(scintilla_view)
    sys.exit(0 if success else 1)
