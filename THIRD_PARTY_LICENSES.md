# Third-Party Software Licenses

Notepad++ Mac Native bundles, links to, or reuses several third-party
components. This file reproduces the copyright and license notices for each of
them, as required by their respective licenses.

The project itself is licensed under the GNU General Public License v3.0 — see
[LICENSE](./LICENSE). Where a component below carries a copyleft license (GPL),
that license applies to that component's code; permissive licenses (Boost) and
attribution licenses (Scintilla/Lexilla HPND-style) apply to their respective
components as stated.

| Component | Upstream | License |
|---|---|---|
| Notepad++ | https://github.com/notepad-plus-plus/notepad-plus-plus | GNU GPL v3 |
| Scintilla | https://www.scintilla.org/ | HPND-style (below) |
| Lexilla | https://www.scintilla.org/Lexilla.html | HPND-style (below) |
| Boost.Regex | https://www.boost.org/ | Boost Software License 1.0 |

---

## Notepad++

Used for: the platform-neutral resource set (`langs.model.xml`,
`stylers.model.xml`, `installer/APIs/*`, `installer/functionList/*`,
`installer/themes/*`, the chameleon pencil icon), the `boostregex` C++ regex
bridge sources, and as the reference baseline for the native port. The native
application code is a derivative work of Notepad++ and is therefore distributed
under the same GNU GPL v3.

```
Notepad++
Copyright (C) 2021 Don HO <don.h@free.fr>
https://notepad-plus-plus.org/

This program is free software; you can redistribute it and/or modify it
under the terms of the GNU General Public License as published by the Free
Software Foundation; Version 3 with the clarifications and exceptions
described by the upstream project.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.

Full license text: https://www.gnu.org/licenses/gpl-3.0.html
```

---

## Scintilla

Used for: the bundled `Scintilla.framework` Cocoa editing surface
(`Contents/Frameworks/Scintilla.framework` in the packaged app), built from
the `scintilla/` tree of upstream Notepad++.

```
License for Scintilla and SciTE

Copyright 1998-2021 by Neil Hodgson <neilh@scintilla.org>
All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation.

NEIL HODGSON DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS
SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS, IN NO EVENT SHALL NEIL HODGSON BE LIABLE FOR ANY
SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE
OR PERFORMANCE OF THIS SOFTWARE.
```

---

## Lexilla

Used for: the bundled `liblexilla.dylib` lexer library
(`Contents/Frameworks/liblexilla.dylib` in the packaged app), built from the
`lexilla/` tree of upstream Notepad++ and loaded at runtime to create `ILexer5`
instances passed to Scintilla.

```
License for Lexilla, Scintilla, and SciTE

Copyright 1998-2021 by Neil Hodgson <neilh@scintilla.org>
All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation.

NEIL HODGSON DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS
SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS, IN NO EVENT SHALL NEIL HODGSON BE LIABLE FOR ANY
SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE
OR PERFORMANCE OF THIS SOFTWARE.
```

---

## Boost.Regex

Used for: the Notepad++/Boost-flavoured regular expression engine, compiled
from the `boostregex/` tree of upstream Notepad++ through the
`CBoostRegexBridge` target and linked into the application. This provides
upstream-compatible regex syntax (`\<`/`\>` word boundaries, `\K`, recursion,
conditionals, atomic groups, etc.).

```
Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in object code executed by a computer system. However,
the aggregate of source code corresponding to the Software or portions
thereof, or derivative works thereof, must be accompanied by the
corresponding source code unless the sole form in which the Software or
derivative works are executed is by means of a computer system.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
```
