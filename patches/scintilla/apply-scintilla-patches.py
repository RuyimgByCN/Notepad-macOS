#!/usr/bin/env python3
"""Apply Scintilla cocoa patches for macOS 26+ compatibility."""
import sys

def apply_display_layer_patch(filepath):
    """Add displayLayer: method to SCIContentView for macOS 26+ layer-backed rendering.
    
    macOS 26 forces layer-backed rendering on all NSViews. SCIContentView's drawRect:
    relies on CGContextCurrent() which returns NULL in displayLayer:. 
    Instead of calling [self display] (which would recurse back into displayLayer:),
    we create a bitmap CGContext and draw into it, then set the result as the layer contents.
    """
    # The marker is the SCIContentView drawRect implementation
    marker = '''	if (!mOwner.backend->Draw(rect, context)) {
		dispatch_async(dispatch_get_main_queue(), ^ {
			[self setNeedsDisplay: YES];
		});
	}
}'''
    
    # Code to insert AFTER the marker
    # NOTE: Must NOT call [self display] or [self setNeedsDisplay]+display
    # because that would recurse back into displayLayer: and crash with stack overflow.
    # Instead, create a bitmap context, call Draw(), and set the layer contents.
    insert_code = '''

//--------------------------------------------------------------------------------------------------

/**
 * macOS 26+ (Tahoe) forces layer-backed rendering on all NSViews.
 * When layer-backed, AppKit calls displayLayer: instead of drawRect:
 * to render. SCIContentView's drawRect: uses CGContextCurrent() which
 * is NULL in displayLayer:. Calling [self display] would recurse into
 * displayLayer: causing stack overflow (RECURSION LEVEL >12000).
 *
 * Instead: create a CGBitmapContext, call the backend Draw() method
 * with it, and assign the resulting image as the layer contents.
 */
- (void) displayLayer: (CALayer *) layer {
	NSRect bounds = self.bounds;
	CGFloat scale = [self.window backingScaleFactor];
	if (scale < 1.0) scale = 1.0;
	int width = (int)(bounds.size.width * scale);
	int height = (int)(bounds.size.height * scale);
	if (width <= 0 || height <= 0) return;

	CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
	CGContextRef ctx = CGBitmapContextCreate(NULL, width, height, 8, width * 4, colorSpace, kCGImageAlphaPremultipliedLast | kCGBitmapByteOrder32Big);
	CGColorSpaceRelease(colorSpace);
	if (!ctx) return;

	CGContextScaleCTM(ctx, scale, scale);
	// Scintilla uses flipped coordinates (+Y downward)
	CGAffineTransform flip = CGAffineTransformMake(1, 0, 0, -1, 0, bounds.size.height);
	CGContextConcatCTM(ctx, flip);

	if (!mOwner.backend->Draw(bounds, ctx)) {
		// Drawing failed; schedule a retry via setNeedsDisplayInRect:
		// (which uses drawRect: path, NOT displayLayer:)
		[self setNeedsDisplayInRect: bounds];
	}

	CGImageRef image = CGBitmapContextCreateImage(ctx);
	CGContextRelease(ctx);
	layer.contents = (__bridge id)image;
	// layer.contents takes ownership via CA retention; release our reference
	if (image) CGImageRelease(image);
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
