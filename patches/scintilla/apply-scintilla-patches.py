#!/usr/bin/env python3
"""Apply Scintilla cocoa patches for macOS 26+ compatibility."""
import sys

def apply_display_layer_patch(filepath):
    """Add wantsUpdateLayer + displayLayer: to SCIContentView for macOS 26+.

    macOS 26 forces layer-backed rendering on all NSViews. For content views
    inside NSScrollView, AppKit calls updateLayer: (NOT drawRect: or
    displayLayer:) because NSView.wantsUpdateLayer defaults to YES in
    layer-backed mode. updateLayer: only sets layer properties (background
    color, etc.) and does NOT draw custom content — which explains why the
    editor renders as blank white.

    Fix: override wantsUpdateLayer to return NO, forcing AppKit to use
    displayLayer: instead. In displayLayer:, create a CGBitmapContext,
    call Scintilla's Draw() directly, and set the result as layer.contents.
    """
    # The marker is the SCIContentView drawRect implementation
    marker = '''	if (!mOwner.backend->Draw(rect, context)) {
		dispatch_async(dispatch_get_main_queue(), ^ {
			[self setNeedsDisplay: YES];
		});
	}
}'''

    # Code to insert: wantsUpdateLayer override + displayLayer with CGBitmapContext
    # IMPORTANT: wantsUpdateLayer returning NO is the key fix that makes
    # AppKit actually call displayLayer: instead of the blank updateLayer: path.
    insert_code = '''

//--------------------------------------------------------------------------------------------------

// macOS 26+ forces layer-backed rendering on all NSViews. For content
// views inside NSScrollView, AppKit defaults to calling updateLayer:
// (which only sets layer properties like backgroundColor) instead of
// displayLayer: or drawRect:. This leaves the editor blank because
// SCIContentView draws custom text content, not just layer properties.
//
// Override wantsUpdateLayer to return NO — this tells AppKit to use
// displayLayer: for content rendering instead of updateLayer:.
// In displayLayer:, we create a CGBitmapContext, call Scintilla's
// Draw() to render text into it, and assign the resulting CGImage
// as the layer contents.
//
// WARNING: Must NOT call [self display] in displayLayer: — that
// recurses into displayLayer: causing stack overflow (SIGSEGV crash
// with RECURSION LEVEL >12000).

+ (BOOL) wantsUpdateLayer {
	return NO;  // Force AppKit to use displayLayer: for content drawing
}

- (void) displayLayer: (CALayer *) layer {
	NSRect bounds = self.bounds;
	CGFloat scale = [self.window backingScaleFactor];
	if (scale < 1.0) scale = 2.0;  // Default to Retina if no window yet
	int width = (int)ceil(bounds.size.width * scale);
	int height = (int)ceil(bounds.size.height * scale);
	if (width <= 0 || height <= 0) return;

	CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
	CGContextRef ctx = CGBitmapContextCreate(NULL, width, height, 8,
		width * 4, cs, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
	CGColorSpaceRelease(cs);
	if (!ctx) return;

	// Set up context to match AppKit's drawRect: coordinate system for a
	// flipped view (isFlipped=YES): origin at top-left, +Y going downward.
	CGContextScaleCTM(ctx, scale, scale);  // Retina scaling
	CGContextTranslateCTM(ctx, 0, bounds.size.height);
	CGContextScaleCTM(ctx, 1.0, -1.0);    // Flip Y axis

	// Render Scintilla content into this bitmap context
	BOOL succeeded = mOwner.backend->Draw(bounds, ctx);

	// Assign rendered image as layer contents
	CGImageRef img = CGBitmapContextCreateImage(ctx);
	CGContextRelease(ctx);
	if (img) {
		layer.contents = (__bridge id)img;
		CGImageRelease(img);
	}

	if (!succeeded) {
		// Drawing failed; request retry via setNeedsDisplayInRect:
		// (which triggers displayLayer: on the next cycle)
		[self setNeedsDisplayInRect: bounds];
	}
}'''

    with open(filepath, 'r') as f:
        content = f.read()

    # Remove any existing displayLayer/wantsUpdateLayer implementation
    for remove_marker in ['+ (BOOL) wantsUpdateLayer', '- (void) displayLayer:']:
        if remove_marker in content:
            method_pos = content.find(remove_marker)
            # Find preceding comment block
            comment_pos = content.rfind('//', 0, method_pos)
            if comment_pos != -1:
                line_start = content.rfind('\n', 0, comment_pos)
                if line_start != -1:
                    sep_pos = content.rfind('//--------------------------------------------------------------------------------------------------\n', 0, line_start)
                    remove_start = sep_pos if sep_pos != -1 else line_start + 1
                else:
                    remove_start = method_pos
            else:
                remove_start = method_pos

            # Find end of method (closing brace)
            brace_count = 0
            pos = content.find('{', method_pos)
            while pos < len(content):
                if content[pos] == '{':
                    brace_count += 1
                elif content[pos] == '}':
                    brace_count -= 1
                    if brace_count == 0:
                        break
                pos += 1
            remove_end = pos + 1
            content = content[:remove_start] + content[remove_end:]
            print(f"  Removed existing {remove_marker.strip()} implementation")

    # Find the second occurrence of the marker (SCIContentView)
    pos = content.find(marker)
    if pos == -1:
        print(f"  ERROR: Could not find marker in {filepath}")
        return False

    pos2 = content.find(marker, pos + len(marker))
    if pos2 != -1:
        pos = pos2

    insert_pos = pos + len(marker)
    content = content[:insert_pos] + insert_code + content[insert_pos:]

    with open(filepath, 'w') as f:
        f.write(content)

    print(f"  Applied: wantsUpdateLayer=NO + displayLayer CGBitmapContext patch to {filepath}")
    return True

if __name__ == '__main__':
    scintilla_view = sys.argv[1] if len(sys.argv) > 1 else 'upstream/notepad-plus-plus/scintilla/cocoa/ScintillaView.mm'
    success = apply_display_layer_patch(scintilla_view)
    sys.exit(0 if success else 1)
