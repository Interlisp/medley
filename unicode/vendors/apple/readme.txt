Name: 0README.TXT

Background information - mapping tables for the Mac(TM) OS
    Version 6: Nov. 15, 1995 - update info for Hebrew and Thai
    (Version 5: Apr. 15, 1995)
    Peter Edberg, Apple Computer, Inc. <edberg1@applelink.apple.com>
    Copyright (C) 1995 by Apple Computer, Inc., all rights reserved.


0. Preliminaries
----------------

For maximum interchangeability, this file and the accompanying MacOS 
mapping tables use only ASCII characters and are intended to be 
displayed in a monospaced font. Every line terminates with carriage 
return.

Apple, the Apple logo, Mac, and Macintosh are trademarks of Apple 
Computer, Inc., registered in the United States and other countries. 
QuickDraw and TrueType are trademarks of Apple Computer, Inc. Unicode is 
a trademark of Unicode Inc. PostScript is a trademark of Adobe Systems 
Inc., which may be registered in certain jurisdictions. IBM is a 
registered trademark of International Business Machines Corporation. ITC 
Zapf Dingbats is a registered trademark of the International Typeface 
Corporation. For the sake of brevity, throughout this document and the 
accompanying tables, "Unicode" can be used to refer to the Unicode 
standard.

Apple Computer, Inc. ("Apple") makes no warranty or representation, 
either express or implied, with respect to this document and the 
accompanying tables, their quality, accuracy, or fitness for a 
particular purpose. In no event will Apple be liable for direct, 
indirect, special, incidental, or consequential damages resulting from 
any defect or inaccuracy in this document or the accompanying tables.

1. Introduction
---------------

In order to understand the accompanying MacOS mapping tables, you will 
need to understand something about the MacOS Unicode Converter. This 
converter has been designed to handle the complex issues that can arise 
when converting between Unicode and other character sets, including:
* Round-trip fidelity (and the use of corporate characters);
* Supporting various mapping tolerance levels (strict, loose), in order
  to provide both round-trip fidelity and a way to handle characters
  that have multiple or ambiguous semantics in some character sets;
* Handling character set variants and extensions, which may require
  selective inclusion or exclusion of certain mappings or sets of
  mappings;
* Mapping single characters in one set to multiple characters in another
  or vice versa (in general, a match may map a sequence of 1 to n
  characters in one set to a sequence of 0 to m characters in another);
* Handling mappings that may depend on attributes such as resolved
  character direction, vertical or horizontal display direction, etc.

The above issues are described in more detail in sections 2-6. Section 7 
provides some general information on MacOS character sets and a list of 
MacOS character encodings.

This document and all of the accompanying mapping tables and character 
lists are preliminary and subject to change. Updated documents and 
tables will be available from the Unicode Inc. ftp site (unicode.org), 
the Apple ftp site (ftp.info.apple.com), the Apple Computer World-Wide 
Web pages (http://www.info.apple.com), and possibly on diskette from 
APDA (Apple's mail-order distribution service for developers).

2. Round-trip fidelity and corporate characters
-----------------------------------------------

For the various national and international standards that were sources 
for Unicode, Unicode provides round-trip fidelity: Text in one of those 
encodings can be mapped to Unicode and back again with no loss of 
information. Characters which were distinct in the source standard are 
distinct in Unicode.

However, Unicode does not attempt to provide round-trip fidelity for 
most vendor standards. Nevertheless, Apple and other platform vendors 
may need to provide such round-trip fidelity for their current encodings 
(this can be important in file systems, for example). In order to do 
this, Apple maps some characters in the current MacOS encodings to 
character codes at the upper end of the Unicode private use area (i.e. 
the corporate use zone). In general, these are characters that are 
rarely used in text that is interchanged with other systems, or
characters for which mistranslation in interchange would have a minimal
impact on most documents. Apple's usage of character codes in the
corporate use zone is documented in the accompanying file
"MacOS_CorpChars".

There is another round-trip fidelity issue that is important for the 
MacOS Unicode converter. Among other things, this converter will be used 
to convert between two non-Unicode encodings by using Unicode as an 
intermediate form. For example, characters in the MacOS standard Roman 
encoding could be converted to ISO/IEC 8859-1 by converting them first
to Unicode, and then converting the Unicode text to ISO/IEC 8859-1.
However, not all MacOS standard Roman characters can be represented in a
distinct way in ISO/IEC 8859-1. In such cases it is useful to know the
subset of MacOS Roman characters that can be converted to 8859-1 and
back (via Unicode) with no loss of information.

3. Mapping tolerance: Strict and loose
--------------------------------------

In many character sets, a single character may have multiple semantics, 
either by explicit definition, ambiguous definition, or established 
usage. For example, the JIS character 0x2142 (Shift-JIS 0x8161) is 
specified in the JIS X0208 standard to have two meanings: "double 
vertical line" and "parallel". Each of these meanings corresponds to a 
different Unicode character: 0x2016 "DOUBLE VERTICAL LINE" and 0x2225 
"PARALLEL TO". When mapping from Unicode to JIS, it is normally 
desirable to map both of these Unicode characters to the single JIS 
character 0x2142. However, when mapping this JIS character to Unicode, 
we can choose only one of the possible Unicode characters.

For some character set X, the converse of the X-to-Unicode mappings are 
called "strict" mappings from Unicode to X. In general, strict mappings 
permit roundtrip conversion from Unicode to X and back for a subset of 
Unicode characters. Strict mappings are useful when round-trip fidelity 
is desired for an X-to-Unicode-to-Y mapping.

For some characters in X, there may be additional mappings from Unicode 
that fall within the range of explicit or established usage for those 
characters; these are called "loose" mappings. It is important to note 
that the range of allowed loose mappings is determined by the character 
set X.

Furthermore, in some cases it is helpful to map a Unicode character to a 
sequence of one or more target characters that may not have the same 
meaning or use, but which may provide an approximate graphic 
representation of the corresponding Unicode character. These are called 
"fallback" mappings.

Some examples of strict and loose mappings:

a) In the JIS example above, JIS 0x2142 is usually mapped to Unicode 
0x2016 "DOUBLE VERTICAL LINE". Thus the reverse mapping is a strict 
mapping from Unicode to JIS, while mapping Unicode 0x2225 "PARALLEL TO" 
to JIS 0x2142 is a loose mapping.

b) When mapping ASCII to Unicode, 0x0A "line feed" and 0x0D "carriage 
return" are usually mapped to the Unicode code points 0x000A and 0x000D. 
When mapping Unicode to ASCII, loose mappings could include mapping 
0x2028 "LINE SEPARATOR" to 0x0A and mapping 0x2029 "PARAGRAPH SEPARATOR" 
to 0x0D.

c) Other loose mappings from Unicode to ASCII might include mapping 
Unicodes 0x2010 "HYPHEN" and 0x2212 "MINUS SIGN" to ASCII 0x2D "hyphen-
minus".

d) In the conventional mapping from ISO/IEC 8859-1 to Unicode, the
8859-1 character 0xE0 "small letter a with grave accent" is mapped to
Unicode 0x00E0 "LATIN SMALL LETTER A WITH GRAVE", so the reverse mapping
is a strict mapping from Unicode to 8859-1. However, the two-character 
Unicode sequence 0x0061+0x0300 ("LATIN SMALL LETTER A" + "COMBINING 
GRAVE ACCENT") can also be mapped to 8859-1 0xE0 as a loose mapping.

e) Since Shift-JIS distinguishes halfwidth and fullwidth characters, 
loose mappings for Shift-JIS must also keep these distinct. For example, 
Shift-JIS 0x814D (JIS 0x212E) "grave accent [fullwidth]" is often mapped 
to Unicode 0xFF40, "FULLWIDTH GRAVE ACCENT", and the reverse is a strict 
mapping. In this case the Unicode sequence 0x3000+0x0300 "IDEOGRAPHIC 
SPACE" + "COMBINING GRAVE ACCENT" can also be mapped to Shift-JIS 0x814D 
as a loose mapping. However, the Unicode sequence 0x0020+0x0300 "SPACE" 
+ "COMBINING GRAVE ACCENT" should not be mapped to Shift-JIS 0x814D as a 
loose mapping, although this sequence could be mapped to Shift-JIS 0x60 
"grave accent [halfwidth]" as a loose mapping.

Although the MacOS Unicode converter (and its tables) supports strict, 
loose, and fallback mappings, the MacOS character mapping tables 
accompanying this document provide only the strict mappings.

4. Character set variants and extensions
----------------------------------------

An example illustrates this issue:

The MacOS standard Japanese character set is based on Shift-JIS with 
some additional characters. The additions include:
(a) For one-byte characters, five additions and one modification.
(b) Separately-encoded vertical forms for some punctuation and kana
    characters from JIS rows 1, 4, and 5. These vertical forms are in
    JIS rows 85, 88, and 89.
(c) Apple extension characters, in JIS rows 9-15.

However, in older versions of the Japanese system, some of the fonts 
were based on a different encoding which did not include the Apple 
extension characters and which encoded vertical forms in JIS rows 11, 
14, and 15. Furthermore, PostScript fonts use a different set of 
extensions in rows 9-15.

With the MacOS Unicode converter, several variants can be specified for 
the MacOS Japanese character set:
* The standard set, with extensions and vertical forms;
* A reduced version of the standard set, without the separately encoded
  vertical forms;
* An alternate set that corresponds to the old font variant;
* An alternate set that corresponds to the PostScript variant;
* A basic "least common denominator" set that works with all the old and
  new fonts.

The MacOS Japanese character set mappings provided in the accompanying 
tables cover only the standard character set, but they are grouped into 
three sections: the basic set, the Apple extensions, and the vertical 
forms.

5. Mappings that are not one-to-one
-----------------------------------

In some cases, a character in a non-Unicode character set may map to a 
sequence of characters in Unicode. To handle the reverse mapping, the 
MacOS Unicode converter can break a Unicode stream into appropriate text 
elements (which may consist of more than one Unicode character) and can 
look up multi-character Unicode sequences.

For example, the Apple extensions in the MacOS standard Japanese 
character set include a character for the circled CJK ideograph for 
"big". Although Unicode encodes other circled ideographs as single 
characters, it does not encode this one. However, this character can be 
represented in Unicode as the Unicode sequence 0x5927+0x20DD, the CJK 
ideograph for "big" followed by COMBINING ENCLOSING CIRCLE.

In addition, a single Unicode character (or a multi-character Unicode 
sequence) may map to a sequence of multiple characters in another 
encoding. For example, the Unicode character 0x00BD "VULGAR FRACTION ONE 
HALF" cannot be mapped into the MacOS standard Roman character set as a 
single character, but it can be mapped to the sequence 0x31+0xDA+0x32, 
"digit one" + "fraction slash" + "digit two" (normally this would be a 
loose mapping).

Finally, some Unicode characters may be silently consumed when mapping 
to some other encodings. For example, when mapping from Unicode to the 
MacOS Arabic character set, resolved direction is used to disambiguate 
some mappings (this is discussed in the next section). Direction 
override characters (Unicodes 0x202C-0x202E) may be used to control the 
resolved direction to achieve proper results. Having fulfilled this 
role, the direction override characters can then be discarded. They are 
included among the Unicode characters that can be represented in the 
MacOS Arabic set (they are represented by the direction inherent in 
certain characters), but there is no specific output character that 
corresponds to them.

The accompanying mapping tables for the MacOS Japanese character set and 
the MacOS Arabic character set include one-to-many mappings.

6. Mappings that depend on attributes
-------------------------------------

Mappings from Unicode to other character sets may depend on attributes 
such as resolved character direction, the state of symmetric swapping, 
and whether the text should use vertical form codes if available (i.e.
whether the text is intended for vertical display on a system that
cannot automatically substitute vertical forms).

a) Resolved character direction

The MacOS Arabic character set was developed in 1986-1987. At that time 
the bidirectional line layout algorithm used in the MacOS was fairly 
simple; it used only a few direction classes (instead of the 13 or so 
now used in the Unicode bidirectional algorithm). In order to permit 
users to handle some tricky layout problems, certain punctuation and 
symbol characters have duplicate code points, one with a left-right 
direction attribute and the other with a right-left direction attribute.

For example, ampersand is encoded at 0x26 with a left-right attribute, 
and at 0xA6 with a right-left attribute. However, there is only one 
ampersand character in Unicode. We need to have a way to map both of the
MacOS Arabic ampersand characters to Unicode and back again without loss
of information. Mapping one of the MacOS Arabic ampersand characters to
a code in the Unicode corporate use zone is undesirable, since both of
the ampersand characters are likely to be used in text that is
interchanged with other systems.

The problem is solved with the use of direction override characters and 
direction-dependent mappings. When mapping from the MacOS Arabic 
character set to Unicode, such problem characters are surrounded with an 
appropriate direction override:
    MacOS Arabic 0x26 ampersand (left)
        -> Unicode 0x202D (LRO) + 0x0026 (AMPERSAND) + 0x202C (PDF)
    MacOS Arabic 0xA6 ampersand (right)
        -> Unicode 0x202E (RLO) + 0x0026 (AMPERSAND) + 0x202C (PDF)
The mappings from Unicode to MacOS Arabic can be disambiguated by the
use of resolved direction:
    Unicode 0x0026 -> MacOS Arabic 0x26 (if L) or 0xA6 (if R)

Direction overrides are also used for some other purposes in mapping 
MacOS Arabic characters to Unicode. For example, the single MacOS Arabic 
ellipsis character has direction class right-left, while the Unicode 
HORIZONTAL ELLIPSIS character has direction class neutral. When mapping 
the MacOS ellipsis to Unicode, it is surrounded with a direction 
override to help preserve proper text layout. However, resolved 
direction is not needed or used when mapping the Unicode HORIZONTAL 
ELLIPSIS back to MacOS Arabic.

b) Symmetric swapping

In loose mappings from Unicode to the MacOS Arabic character set, the 
state of symmetric swapping (which may be changed by the Unicode 
characters 0x206A, 0x206B) affects the mapping of paired characters such 
as punctuation and brackets. This does not affect the strict mappings 
given in the accompanying tables.

c) Horizontal or vertical display

As noted above, the MacOS standard Japanese character set (for 
historical reasons) includes separately-encoded vertical forms for some 
punctuation and kana. When Unicode characters in the CJK punctuation and 
kana ranges are mapped to MacOS Japanese characters and (1) those 
characters are intended for vertical display, (2) they will be displayed 
in an environment that does not provide automatic vertical form 
substitution, and (3) loose mappings are being used, a vertical display 
attribute can be used to map certain Unicode characters to the 
corresponding vertical form codes in the MacOS Japanese character set.

Note that this capability is only used for loose mappings, and does not 
affect the strict mappings given in the accompanying tables. Also note 
that this does not affect mapping of the Unicode vertical presentation 
forms (which always map to the MacOS Japanese vertical form codes if 
those codes are available in the specified variant). Finally, note that 
the QuickDraw(TM) GX display environment does provide automatic vertical 
forms substitution with appropriate fonts.

7. MacOS character sets
---------------------------

The MacOS can support multiple character sets. In the current MacOS  
architecture these character sets are distinguished primarily by script 
code: font family IDs are grouped into ranges, and each range is 
associated with a script code. 

In some cases, there are several variant encodings that share a single 
script code. Usually these are minor variants. To distinguish these 
variants, additional information is required, such as font name or 
system localization code.

The encodings described here (and in the accompanying tables) are the 
encodings used in MacOS versions 7.1 and later. In some cases, certain 
earlier system versions have used variants of these encodings.

In all MacOS encodings, character codes 0x00-0x7F are identical to ASCII 
(except for MacOS Japanese, which changes reverse solidus to yen sign). 
Fonts used as "system" fonts (for menus, dialogs, etc.) have four glyphs 
at code points 0x11-0x14 for transient use by the Menu Manager. These 
glyphs are not intended as characters for use in normal text, and the 
associated code points are not generally interpreted as associated with 
these glyphs. (However, a "system font variant" mapping table could 
provide mappings for these).

Note that in general, character sets cannot be determined from font 
layouts (they are not the same thing!). This is most noticeable with 
Arabic, Hebrew, and Devanagari.

The following is a list of current MacOS character sets. The 
accompanying tables provide mappings from many of these encodings to 
Unicode.

a) MacOS encodings for script code 0, smRoman.

* Standard Roman - this is the default for script code 0 (when the
  special cases listed below do not apply). It covers several western
  European languages, and includes math operators and various symbols.

* Symbol - this is the encoding for the font named "Symbol". It includes
  Greek letters, math operators, and miscellaneous symbols. The layout
  of the Symbol character set is identical to the layout of the Adobe
  Symbol encoding vector, with the addition of the Apple logo at 0xF0.
  The Symbol character set encodes some glyph fragments (of arrows,
  brackets, etc.) as well as both serif and sans-serif forms for
  copyright, registered, and trade mark sign; round-trip mapping of
  these characters requires the use of corporate characters.

* Dingbats - this is the encoding for the font named "Zapf Dingbats".
  The layout of the Dingbats character set is identical to or a superset
  of the layout of the Adobe Zapf Dingbats encoding vector.

* Turkish - this is the encoding if the script code is 0 and the system
  region code (system localization) is 24, verTurkey. It has 7 code
  point differences from standard Roman.

* Croatian - this is the encoding if the script code is 0 and the system
  region code is 68, verCroatia (or 25, verYugoCroatian, only used in
  older systems). It has 20 code point differences from standard Roman,
  but only 10 differences in repertoire.

* Icelandic - this is the encoding if the script code is 0 and the
  system region code is 21, verIceland. It has 6 code point differences
  from standard Roman.

* Romanian - this is the encoding if the script code is 0 and the system
  region code is 39, verRomania . It has 6 code point differences from
  standard Roman.

* Standard Greek (monotonic) - this is the encoding if the script code
  is 0 and the system region code is 20, verGreece. Although a script
  code is defined for Greek, the Greek localized system does not use it
  (the font family IDs are in the smRoman range). This encoding is based
  on the ISO/IEC 8859-7 repertoire with additional Roman characters for
  French and German, as well as additional symbols.
  Greek system 4.1 used a different encoding that matched 8859-7 code
  points for Greek letters. Greek system 6.0.7 also used a variant of
  the standard encoding, but it was quickly replaced by Greek system
  6.0.7.1 which used the standard encoding.
  NOTE- The Greek Language Kit, when released, will use the Greek script
  code (its Greek fonts will have family IDs in the smGreek range); see
  notes under script code 6 below.

  See also the Central European Roman encoding under script code 29
  below.

b) MacOS encodings for script code 1, smJapanese.

* Standard Japanese - this is the default for script code 1. As
  described above, it is based on a Shift-JIS implementation of JIS
  X0208-1990 ("fullwidth") and JIS X0201-1976 ("halfwidth"), with 5
  additional one-byte characters and one modified character, a set of
  Apple extension characters which include many industry standard
  extensions, and separate codes for vertical forms of some punctuation
  and kana.

  There are two variants of standard Japanese associated with specific
  fonts: (1) For MaruGothic and HonMincho TrueType fonts in system
  software release J-7.1 and Japanese Language Kit 1.0, and (2) for the
  PostScript fonts Gothic BBB and Ryumin, which are used with the screen 
  fonts ChuGothic and SaiMincho. Although they are supported by the
  MacOS Unicode converter, these variants are not documented here or
  in the accompanying tables. The MacOS Unicode converter also
  supports some artificial variants which are just subsets of the
  standard Japanese encoding.

c) MacOS encodings for script code 2, smTradChinese.

* Standard Traditional Chinese - this is an extension of Big-5.

d) MacOS encodings for script code 3, smKorean.

* Standard Korean - this is a "shifted" implementation of KSC 5601-1987
  (0xA0 is added to the row and to the column), with some additional
  characters.

e) MacOS encodings for script code 4, smArabic.

* Standard Arabic - This is based on the ISO/IEC 8859-6 repertoire, with
  additional Arabic letters for Persian and Urdu and with additional
  Roman letters for European languages. It has the interesting feature
  mentioned above that certain ASCII punctuation and symbol characters
  are encoded twice, once for each direction. Digit character codes
  0x30-0x39 have left-to-right directionality, and may be displayed with 
  either European digit forms or Arabic digit forms depending on
  context. Digit codes 0xB0-0xB9 have right-left directionality and are
  always displayed with Arabic digit forms; these are used for special
  layout situations such as part numbers.

f) MacOS encodings for script code 5, smHebrew.

* Standard Hebrew - This is based on the ISO/IEC 8859-8 Hebrew letter
  repertoire, but adds Hebrew points, some Hebrew ligatures, some
  additional Roman letters for European languages, and some non-ASCII
  punctuation. As with standard Arabic, certain ASCII punctuation and
  symbol characters are encoded twice, once for each direction. This
  is also true for the European digits.
  
  There is one minor variant of standard Hebrew associated with
  certain fonts, in which LEFT SINGLE QUOTATION MARK at 0xD4 is
  replaced by FIGURE SPACE.

g) MacOS encodings for script code 6, smGreek.

  This script code will refer to the encoding used with the Greek
  Language Kit, when released. It will either be the standard Greek
  encoding described above, or a variant that supports polytonic Greek.

h) MacOS encodings for script code 7, smCyrillic.

* Standard Cyrillic - this is the default for script code 7 (when the
  special cases listed below do not apply). It is based on the ISO/IEC
  8859-5 Cyrillic character repertoire.

* Ukrainian - this is the encoding if the script code is 7 and the
  system region code (system localization) is 62, verUkraine. It has 2
  code point differences from standard Cyrillic (it adds a case pair
  for GHE WITH UPTURN).

* Bulgarian -

  An additional Cyrillic variant has been defined to cover the Cyrillic
  characters needed for the languages of the central Asian republics
  (plus Russian): Uzbek, Kazakh, Kirghiz, Azerbaijani, Turkmen, Tajik).

i) MacOS encodings for script code 9, smDevanagari.

* Standard Devanagari - This is an extension of IS 13194:1991 (ISCII-91)
  but is not yet fully defined. The Devanagari encoding used in system
  software versions 6.x was different, and was based on ISCII-88.

j) MacOS encodings for script code 21, smThai.

* Standard Thai - This is based on TIS 620-2533, except that three of
  the TIS 620-2533 characters are replaced with other characters. Some
  undefined code points in TIS 620-2533 are used for additional
  punctuation characters.

k) MacOS encodings for script code 25, smSimpChinese.

* Standard simplified Chinese - this is a "shifted" implementation of
  GB 2312-1980 (0xA0 is added to the row and to the column), with some
  additional characters.

l) MacOS encodings for script code 29, smEastEurRoman.

* Standard Central European - This is similar to standard Roman, but
  with a different (and larger) set of European characters and with 
  fewer symbols. It covers several Slavic languages (Czech, Polish,
  Slovak, Slovenian), Hungarian, and the languages of the Baltic
  republics (Estonian, Latvian, Lithuanian).


FILE LIST:
The file names here have been changed from the original files
previously published on the Unicode.org FTP server.  The mapping
is as follows:

Original Name		"8.3" Name
-------------------	------------
MacOS-ReadMe.txt	0README.TXT
MacOS_Cyrillic.txt	CYRILLIC.TXT
MacOS_Japanese.txt	JAPAN.TXT
MacOS_Turkish.txt	TURKISH.TXT
MacOS_Arabic.txt	ARABIC.TXT
MacOS_Dingbats.txt	DINGBAT.TXT
MacOS_Roman.txt		ROMAN.TXT
MacOS_Ukrainian.txt	UKRAINE.TXT
MacOS_CentralEuro.txt	CNTEURO.TXT
MacOS_Greek.txt		GREEK.TXT
MacOS_Romanian.txt	ROMANIA.TXT
MacOS_CorpChars.txt	CORPCHR.TXT
MacOS_Hebrew.txt	HEBREW.TXT
MacOS_Symbol.txt	SYMBOL.TXT
MacOS_Croatian.txt	CROATIAN.TXT
MacOS_Icelandic.txt	ICELAND.TXT
MacOS_Thai.txt		THAI.TXT

