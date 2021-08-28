#=======================================================================
#   File name:  README.TXT
#
#   Contents:   Background information on Unicode mapping tables for
#               Mac OS legacy text encodings
#
#   Copyright:  (c) 1995-2002, 2005 by Apple Computer, Inc., all rights
#               reserved.
#
#   Contact:    charsets@apple.com
#
#   Changes:
#
#       c02  2005-Apr-04    Update discussion of roundtrip fidelity,
#                           delete discussion of mappings dependent on
#                           symmetric swapping (no longer supported),
#                           provide information on how legacy encodings
#                           are supported in Mac OS X.
#      b3,c1 2002-Dec-19    Add Keyboard font encoding. Update URLs,
#                           notes.
#       b02  1999-Sep-22    Update information on Cyrillic. Update
#                           contact e-mail address.
#       n07  1998-Feb-05    Rewrite to provide additional information
#                           relevant to using the accompanying mapping
#                           tables, and to delete some extraneous
#                           information. Delete Bulgarian (no special
#                           encoding, uses standard Cyrillic), add
#                           Farsi, Devanagari, Gurmukhi, Gujarati,
#                           Celtic, Gaelic, Inuit, Tibetan.
#       n04  1995-Nov-15    Update info for Hebrew and Thai
#       n03  1995-Apr-15    First version (after fixing some typos).
#
##################

0. Preliminaries
----------------

For maximum interchangeability, this file and the accompanying Mac OS
mapping tables use only ASCII characters. They are intended to be
displayed in a monospaced font.

Apple, the Apple logo, Mac, and Macintosh are trademarks of Apple
Computer, Inc., registered in the United States and other countries.
QuickDraw and TrueType are trademarks of Apple Computer, Inc. Unicode is
a trademark of Unicode Inc. PostScript is a trademark of Adobe Systems
Inc., which may be registered in certain jurisdictions. IBM is a
registered trademark of International Business Machines Corporation. ITC
Zapf Dingbats is a registered trademark of the International Typeface
Corporation. For the sake of brevity, throughout this document and the
accompanying tables, "Macintosh" can be used to refer to Macintosh
computers and "Unicode" can be used to refer to the Unicode standard.

Apple Computer, Inc. ("Apple") makes no warranty or representation,
either express or implied, with respect to this document and the
accompanying tables, their quality, accuracy, or fitness for a
particular purpose. In no event will Apple be liable for direct,
indirect, special, incidental, or consequential damages resulting from
any defect or inaccuracy in this document or the accompanying tables.

1. Introduction
---------------

This document summarizes some Unicode mapping considerations that are
relevant for the accompanying mapping tables. It also provides an
overview of Mac OS legacy encodings.

These mapping tables and character lists are subject to change. The
latest tables should be available from the following:

<http://www.unicode.org/Public/MAPPINGS/VENDORS/APPLE/>

2. Round-trip fidelity and overview of mapping techniques
---------------------------------------------------------

For a particular set of national and international standards, Unicode
provides round-trip fidelity: Text in one of those encodings can be
mapped to Unicode and back again, yielding the original characters.
Characters which are distinct in one of these source standards have a
distinct counterpart in Unicode. Note that this counterpart might not be
a single Unicode character; as is pointed out in "The Unicode Standard,
Version 2.0" (page 2-10), "sometimes a single code value in another
standard corresponds to a sequence of code values in the Unicode
Standard, or vice versa."

However, Unicode does not attempt to provide round-trip fidelity for
most vendor standards. Nevertheless, Apple and other platform vendors
may need to provide such round-trip fidelity for their current platform
encodings and/or legacy platform encodings (this can be important in
file systems, for example). In order to do this, Apple makes use of some
Unicode characters in the corporate-use zone (the upper end of the
private use area).

Corporate-zone characters must be used with care. Indiscriminate use of
such characters can result in text which is not easily interchanged with
other systems, since these characters have no standard meaning outside a
particular platform. The mappings provided here are intended to minimize
the use of private use characters, or to use them in such a way that
basic text content will not be lost if the corporate zone characters are
dropped when text is transferred to another system.

The tables provided here have three goals, in the following order of
importance:
1. Provide 100% round-trip mapping from a Mac OS legacy encoding to
Unicode and back.
2. Map characters in a Mac OS encoding into the Unicode characters that
best represent the interpretation and usage of the Mac OS characters.
3. When mapping text in a Mac OS encoding to Unicode using the tables,
the resulting Unicode text should be as interchangeable as possible.

To satisfy these goals, the mappings use a variety of techniques. First
we attempt to achieve round-trip mappings using any standard Unicode
feature at our disposal, without resorting to corporate-zone characters.
This can includes the following techniques:
- Use of all Unicode characters defined in Unicode 2.1 and later,
  including compatibility characters.
- Mapping a single character in a Mac OS encoding to a sequence of
  standard Unicode characters, or vice versa. This requires grouping
  characters into appropriate chunks for lookup before mapping them
  (this mainly applies to sequences of Unicode characters).
- Using Unicode direction overrides to force direction attributes when
  mapping to Unicode. This requires resolution of Unicode character
  direction, and use of this information, when mapping from Unicode back
  to certain Mac OS encodings.
The requirements imposed on Unicode handling are necessary for other,
non-transcoding operations in a full Unicode implementation anyway, so
requiring them for transcoding should not impose much of a burden.

Next, if round-trip fidelity cannot be achieved using the above
techniques, we attempt to use corporate-zone characters only as
"transcoding hints" (more on this below). These are combined with one or
more standard Unicode characters to mark them as special for
transcoding, but have no other function and can be deleted with no loss
of basic text content (only of round-trip fidelity).

Finally, if a character in a Mac OS encoding is unrelated to any Unicode
character or Unicode character sequence, we may map it to a single
corporate-zone Unicode code point.

These techniques are described in more detail in the following sections.

Some clients of these tables may have a different set of goals. For
example, some clients may prefer to avoid compatibility characters,
perhaps sacrificing round-trip fidelity if necessary. In most cases it
is fairly easy to construct other types of mappings from the mappings
given here. In particular, the Unicode mappings here have been designed
so that if they are converted to a restricted form of NFD (a form that
does NOT decompose or normalize Unicode characters in the ranges
2000-2FFF or F900-FAFF), the resulting mappings still provide roundtrip
fidelity. (For certain characters in the Mac OS Hebrew and Devanagari
encodings, the decomposition mappings must use a grouping transcoding
hint to ensure roundtrip fidelity; more details on this are provided in
the mapping tables for those encodings.)

There is one more round-trip issue that should be mentioned. If a
Unicode character or sequence can be mapped at all into a particular Mac
OS encoding, then the reverse mapping back to Unicode should yield the
original Unicode character or sequence (except for possible differences
in direction overrides or other Unicode characters with General Category
Cf). The tables here also provide this. For a related issue, see the
next section.

3. Mapping tolerance: Strict and loose
--------------------------------------

In many character sets, a single character may have multiple semantics, 
either by explicit definition, ambiguous definition, or established 
usage. For example, the JIS character 0x2142, or 0x8161 in Shift-JIS, 
is specified in the JIS X0208 standard to have two meanings: "double 
vertical line" and "parallel". Each of these meanings corresponds to a 
different Unicode character: 0x2016 DOUBLE VERTICAL LINE and 0x2225 
PARALLEL TO. When mapping from Unicode to Shift-JIS, it is normally 
desirable to map both of these Unicode characters to the single
Shift-JIS character. However, when mapping the Shift-JIS character to
Unicode, we can choose only one of the possible Unicode characters.

For two encodings X and Y, we can define a set of "strict" mappings
from one to the other as follows: If text in X can be mapped to Y using
the strict mappings from X to Y, then the resulting text can be mapped
back using the strict mappings from Y to X to end up with the original
text from X. Similarly, if text in Y can be mapped to X using the strict
mappings from Y to X, then the resulting text can be mapped back using
the strict mappings from X to Y to end up with the original text from Y.

There may be several characters in one encoding that all map to a
single character in another encoding, but only one of these mappings
can be strict; the others are "loose".

The mappings given in the accompanying tables are strict mappings.
However, the Mac OS Text Encoding Converter also supports loose
mappings and fallback mappings. Some of the accompanying tables provide
suggestions about possible loose mappings.

4. Mapping a Mac encoding character to a Unicode sequence or vice versa
-----------------------------------------------------------------------

In some cases, a character in a Mac OS legacy encoding maps to a
sequence of Unicode characters. For example, the Mac OS Japanese
encoding includes a character for the circled CJK ideograph "big".
Although Unicode encodes other circled ideographs as single characters,
it does not encode this one. However, this character can be
unambiguously represented in Unicode as the Unicode sequence
0x5927+0x20DD, the CJK ideograph for "big" followed by COMBINING
ENCLOSING CIRCLE.

To handle the reverse mapping, a transcoding process must group the
Unicode sequence 0x5927+0x20DD as a single element for lookup (The
Mac OS Text Encoding Converter does this).

In a few cases, a sequence of characters in a Mac OS legacy encoding
must be grouped for mapping to a single Unicode character or a sequence
of Unicode characters. For example, in Mac OS Devanagari (based on
ISCII-91), DEVANAGARI LETTER VOCALIC L is represented as 0xA6+0xE9;
but this is represented in Unicode by the single character 0x090C.
Furthermore, explicit halant is represented in Mac OS Devanagari as
0xE8+0xE8 (double halant) and in Unicode as 0x094D+0x200C (VIRAMA
plus ZERO WIDTH NON-JOINER). The latter can also be considered as
a context-dependent mapping of 0xE8, halant.

Loose mappings from Unicode to a Mac OS encoding often map a single
Unicode to a sequence of characters in the Mac OS encoding. For example,
the Unicode character 0x00BD VULGAR FRACTION ONE HALF cannot be mapped
into the Mac OS Roman character set as a single character, but it has a
loose mapping to the sequence 0x31+0xDA+0x32, "digit one" + "fraction
slash" + "digit two".

In some cases a Unicode character such as a direction override may
simply be discarded when mapping to a Mac OS encoding, since the
information carried by the override may be represented in a different
way by the Mac OS encoding. See the next section for an example.

5. Mappings that depend on directionality (or other attributes)
---------------------------------------------------------------

Strict mappings from Unicode to Mac OS legacy encodings may depend on
resolved character direction. Loose mappings may depend on additional
attributes such as whether the text should use vertical form codes if
available (i.e. whether the text is intended for vertical display on a
system that cannot automatically substitute vertical forms).

a) Resolved character direction

The Mac OS Arabic and Hebrew character sets were developed in 1986-1987.
At that time the bidirectional line layout algorithm used in the Mac OS
was fairly simple; it used only a few direction classes (instead of the
19 now used in the Unicode bidirectional algorithm). In order to permit
users to handle some tricky layout problems, certain punctuation and
symbol characters have duplicate code points, one with a left-right 
direction attribute and the other with a right-left direction attribute.

For example, plus sign is encoded at 0x2B with a left-right attribute,
and at 0xAB with a right-left attribute. However, there is only one PLUS
SIGN character in Unicode. This leads to some interesting problems when
mapping between Mac OS Arabic or Hebrew and Unicode.

We need a way to map both of these plus signs to Unicode and back. Using
a single corporate character for one of these plus signs is not a good
solution, since both of the plus sign characters are likely to be used
in text that is interchanged, and thus content would be lost.

The problem is solved with the use of direction override characters and
direction-dependent mappings. When mapping from Mac OS Arabic or Hebrew
to Unicode, we use direction overrides as necessary to force the
direction of the resulting Unicode characters. When mapping back from
Unicode, the Unicode bidirectional algorithm should be used to determine
resolved direction of the Unicode characters. The mapping from Unicode
to Mac OS Arabic or Hebrew can then be disambiguated as necessary by
using the resolved direction.

For example, when mapping from Mac OS Arabic or Hebrew, we can use
LEFT-RIGHT OVERRIDE (LRO), RIGHT-LEFT OVERRIDE (RLO), and POP DIRECTION
FORMATTING (PDF) as follows:

  0x2B ->  0x202D (LRO) + 0x002B (PLUS SIGN) + 0x202C (PDF)
  0xAB ->  0x202E (RLO) + 0x002B (PLUS SIGN) + 0x202C (PDF)

When mapping back, we resolve the direction of the Unicode character
0x002B, and use this information to determine which of the Mac OS
encoding characters to use:

  0x002B -> 0x2B (if LR) or 0xAB (if RL)
  
After direction overrides have been used in this way to force a
particular resolved direction, they may be discarded when mapping from
Unicode to Mac OS Arabic and Hebrew (since the information they carried
in Unicode is represented in the Mac OS encoding by the code point of
the plus sign).

Even when not required for round-trip fidelity, direction overrides
may be used when mapping from a Mac OS encoding to Unicode in order to
preserve proper text layout. For example, the single Mac OS Arabic
ellipsis character has direction class right-left, while the Unicode
HORIZONTAL ELLIPSIS character has direction class neutral. When 
mapping the Mac OS ellipsis to Unicode, it is surrounded with a
direction override to help preserve proper text layout. However,
resolved direction is not needed or used when mapping the Unicode
HORIZONTAL ELLIPSIS back to Mac OS Arabic.

b) Horizontal or vertical display

The Mac OS Japanese encoding includes separately-encoded vertical forms
for some punctuation and kana. When Unicode characters in the CJK
punctuation and kana ranges are mapped to Mac OS Japanese characters and
(1) those characters are intended for vertical display, (2) they will be
displayed in an environment that does not provide automatic vertical
form substitution, and (3) loose mappings are desired, the Unicode
characters can be mapped to the corresponding vertical form codes in the
Mac OS Japanese encoding.

This does not affect mapping of the Unicode vertical presentation forms
(which always map to the Mac OS Japanese vertical form codes).

6. Use of corporate characters
------------------------------

Apple has defined a block of 32 corporate characters as "transcoding
hints." These are used in combination with standard Unicode characters
to force them to be treated in a special way for mapping to other
encodings; they have no other effect. Sixteen of these transcoding
hints are "grouping hints" - they indicate that the next 2-4 Unicode
characters should be treated as a single entity for transcoding. The
other sixteen transcoding hints are "variant tags" - they are like
combining characters, and can follow a standard Unicode (or a sequence
consisting of a base character and other combining characters) to
cause it to be treated in a special way for transcoding. These always
terminate a combining-character sequence.

Whenever possible, mappings that require corporate-zone characters
use standard Unicode characters in combination with a single
transcoding hint (no mapping uses more than one transcoding hint).
For these mappings, even if the corporate-zone characters are lost in
interchange, the basic text content will be preserved.

However, some characters in a Mac OS encoding - such as the Apple
logo character - bear no relation to any standard Unicode character.
In these cases, the Mac OS character is mapped to a single corporate
zone character defined by Apple. Fewer than 40 corporate characters
are used in this way.

All of the corporate characters defined by Apple are listed in the
accompanying file "CORPCHAR.TXT", including old Apple corporate
character assignments which are now deprecated (but which are still
supported as loose mappings by the Mac OS Text Encoding Converter).

7. Font variants
----------------

For some Mac OS legacy encodings, certain fonts used with that encoding
may actually implement a slight variant of the standard encoding
specified in the accompanying mapping tables. The header comments in the
mapping table files for each encoding describe any font variants
associated with that encoding.

8. Encodings in Mac OS X
------------------------

The Mac OS X Cocoa and Carbon environments use Unicode as the primary
text encoding. Some legacy programming interfaces in the Carbon
environment - e.g. Quickdraw Text, the Script Manager, and related
Text Utilities - use and support the following subset of Mac OS legacy
encodings:
  Roman
  Central European
  Cyrillic
  Chinese Traditional
  Chinese Simplified 
  Japanese
  Korean

Other legacy Mac OS encodings are supported in Carbon and Cocoa via
transcoding using the Mac OS Text Encoding Converter or other
transcoding interfaces; the character repertoires of all Mac OS
legacy encodings are supported in Unicode on Mac OS X.

Additional legacy encodings are also supported in the Classic
environment under Mac OS X.

9. Mac OS legacy encodings
--------------------------

Mac OS versions 7.1 and later supported multiple encodings via the
Script Manager, QuickDraw Text and related Text Utilities. These
system components distinguish these encodings primarily by script code:
font family IDs are grouped into ranges, and each range is associated
with a script code. 

In some cases, there are several encodings that share a single script
code. Usually these are closely related. To distinguish among these,
additional information is required, such as font name or system
region code (locale code).

The encodings described here (and in the accompanying tables) are the 
legacy encodings used in Mac OS versions 7.1 and later. In some cases,
certain earlier system versions have used different encodings. Not all
of these encodings are directly supported in Mac OS X, but Mac OS X
does support transcoding between all of these encodings and Unicode.

In all Mac OS legacy encodings, character codes 0x00-0x7F are identical
to ASCII, except that
  - in Mac OS Japanese, reverse solidus is replaced by yen sign
  - in Mac OS Arabic, Farsi, and Hebrew, some of the punctuation in this
    range is treated as having strong left-right directionality,
    although the corresponding Unicode characters have neutral
    directionality
  - in the three symbol glyphs encodings (Symbol, Dingbats, and Keyboard
    glyphs), a different mapping is used for the ASCII range. The
    Keyboard glyphs encoding even has a special mapping for the control
    characters range 0x00-0x1F.
Fonts used as "system" fonts (for menus, dialogs, etc.) had four glyphs
at code points 0x11-0x14 for transient use by the Menu Manager. These
glyphs were not intended as characters for use in normal text, and the
associated code points are not generally interpreted as associated with
these glyphs. (However, a "system font variant" mapping table could
provide mappings for these).

Note that in general, character sets cannot be determined from font 
layouts (they are not the same thing!). This is very noticeable with 
Arabic, Hebrew, and Devanagari, for example.

The following is a list of legacy Mac OS encodings. The accompanying
tables provide mappings from these encodings to Unicode.

a) Mac OS encodings for script code 0, smRoman.

* Roman - this is the default for script code 0 (when the special
  cases listed below do not apply). It covers several western European
  languages, and includes math operators and various symbols.

* Symbol - this is the encoding for the font named "Symbol". It includes
  Greek letters, math operators, and miscellaneous symbols. The layout
  of the Symbol character set is identical to the layout of the Adobe
  Symbol encoding vector, with the addition of the Apple logo at 0xF0
  and the EURO SIGN at 0xA0.

* Dingbats - this is the encoding for the font named "Zapf Dingbats".
  The layout of the Dingbats character set is identical to or a superset
  of the layout of the Adobe Zapf Dingbats encoding vector.

* Keyboard glyphs - this is the encoding for the legacy font named
  ".Keyboard". Before Mac OS X, this font was used by the user-interface
  system to display glyphs for special keys on the keyboard. In Mac OS
  X, this mapping is not associated with a font; it is only used as a
  way to map from a set of Menu Manager constants to associated Unicode
  sequences. As such, new mappings added for Mac OS X only may be
  one-way mappings: From the Keyboard glyph "encoding" to Unicode, but
  not back.

* Turkish - this is the encoding if the script code is 0 and the system
  region code is 24, verTurkey. It has 7 code point differences from
  Mac OS Roman.

* Croatian - this is the encoding if the script code is 0 and the system
  region code is any of the following:
    68, verCroatia
    66, verSlovenian
    25, verYugoCroatian (only used in older systems)
  It has 20 code point differences from standard Roman, but only 10
  differences in repertoire.

* Icelandic - this is the encoding if the script code is 0 and the
  system region code is either of the following:
    21, verIceland
    47, verFaroeIsl
  It has 6 code point differences from standard Roman. It also has one
  font variant.

* Romanian - this is the encoding if the script code is 0 and the system
  region code is 39, verRomania . It has 6 code point differences from
  standard Roman.

* Celtic - this is the encoding if the script code is 0 and the system
  region code is any of the following:
    50, verIreland
    75, verScottishGaelic
    76, verManxGaelic
    77, verBreton
    79, verWelsh
  It is a variant of Mac OS Roman with a few extra accented characters
  for Welsh.

* Gaelic - this is the encoding if the script code is 0 and the system
  region code is 81, verIrishGaelicScript. It is a variant of Mac OS
  Roman, and supports the older Irish orthography using dot above.

* Greek (monotonic) - this is the encoding if the script code is 0 and
  the system region code is 20, verGreece. Although a script code is
  defined for Greek, the Greek localized system does not use it (the
  font family IDs are in the smRoman range). This encoding is based on
  the ISO/IEC 8859-7 repertoire with additional Roman characters for
  French and German, as well as additional symbols. Greek system 4.1
  used a different encoding that matched 8859-7 code points for Greek
  letters. Greek system 6.0.7 also used a variant of the standard
  encoding, but it was quickly replaced by Greek system 6.0.7.1 which
  used the standard encoding.

  See also the Central European encoding under script code 29 below.

b) Mac OS encodings for script code 1, smJapanese.

* Japanese - this is the default for script code 1. It is based on a
  Shift-JIS implementation of JIS X0208-1990 ("fullwidth") and
  JIS X0201-1976 ("halfwidth"), with 5 additional one-byte characters
  and one modified character, a set of Apple extension characters which
  include many industry standard extensions, and separate codes for
  vertical forms of some punctuation and kana. There are several font
  variants.

c) Mac OS encodings for script code 2, smTradChinese.

* Chinese Traditional - this is an extension of Big-5.

d) Mac OS encodings for script code 3, smKorean.

* Korean - this is an extension of EUC-KR.

e) Mac OS encodings for script code 4, smArabic.

* Arabic - This is the default for script code 4 (when the special
  case listed below does not apply). It is based on the ISO/IEC 8859-6
  repertoire, with additional Arabic letters for Persian and Urdu and
  with accented Roman letters for European languages. It has the
  interesting feature mentioned above that certain ASCII punctuation
  and symbol characters are encoded twice, once for each direction. It
  has several font variants.
 
* Farsi - This is the encoding if the script code is 4 and the system
  region code is 48, verIran. It is similar to Mac OS Arabic, but has
  the "extended" or Persian digits instead of the standard Arabic
  digits. It has one font variant.

f) Mac OS encodings for script code 5, smHebrew.

* Hebrew - This is based on the ISO/IEC 8859-8 Hebrew letter repertoire,
  but adds Hebrew points, some Hebrew ligatures, some accented Roman
  letters for European languages, and some non-ASCII punctuation. As 
  with Mac OS Arabic, certain ASCII punctuation and symbol characters
  are encoded twice, once for each direction. This is also true for the
  European digits. This has one font variant.

g) Mac OS encodings for script code 6, smGreek.

  None currently - see smRoman.

h) Mac OS encodings for script code 7, smCyrillic.

* Cyrillic - This is based on the ISO/IEC 8859-5 Cyrillic character
  repertoire plus an additional case pair for Ukrainian.

i) Mac OS encodings for script code 9, smDevanagari.

* Devanagari - This is based on IS 13194:1991 (ISCII-91), and adds some
  punctuation and symbols.

j) Mac OS encodings for script code 10, smGurmukhi.

* Gurmukhi - This is based on IS 13194:1991 (ISCII-91), and adds some
  punctuation and symbols.

k) Mac OS encodings for script code 11, smGujarati.

* Gujarati - This is based on IS 13194:1991 (ISCII-91), and adds some
  punctuation and symbols.

l) Mac OS encodings for script code 21, smThai.

* Thai - This is based on TIS 620-2533, except that three of the
  TIS 620-2533 characters are replaced with other characters. Some
  undefined code points in TIS 620-2533 are used for additional
  punctuation characters.

m) Mac OS encodings for script code 25, smSimpChinese.

* Chinese Simplified - this is an extension of EUC-CN.

n) Mac OS encodings for script code 26, smTibetan.

* Tibetan

o) Mac OS encodings for script code 28, smEthiopic.

* Inuit - this is the encoding if the script code is 28 and the
  system region code is 78, verNunavut (for Inuktitut language).
  There is no script code for Inuit, so it shares the script code
  with Ethiopic.

p) Mac OS encodings for script code 29, smCentralEuroRoman.

* Central European - This is similar to standard Roman, but with a
  different (and larger) set of European characters and with fewer
  symbols. It is used for Polish, Czech, Slovak, Hungarian, Estonian,
  Latvian, and Lithuanian.
