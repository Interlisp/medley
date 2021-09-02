The following files describe windows code page behavior for the "ansi" code pages provided by Microsoft.

File               Code Page       Description

bestfit874.txt     windows-874     ANSI/OEM Thai (same as 28605, ISO 8859-15); Thai (Windows)
bestfit932.txt     shift_jis       ANSI/OEM Japanese; Japanese (Shift-JIS)
bestfit936.txt     gb2312          ANSI/OEM Simplified Chinese (PRC, Singapore); Chinese Simplified (GB2312)
bestfit949.txt     ks_c_5601-1987  ANSI/OEM Korean (Unified Hangul Code)
bestfit950.txt     big5            ANSI/OEM Traditional Chinese (Taiwan; Hong Kong SAR, PRC); Chinese Traditional (Big5)
bestfit1250.txt    windows-1250    ANSI Central European; Central European (Windows) 
bestfit1251.txt    windows-1251    ANSI Cyrillic; Cyrillic (Windows)
bestfit1252.txt    windows-1252    ANSI Latin 1; Western European (Windows) 
bestfit1253.txt    windows-1253    ANSI Greek; Greek (Windows)
bestfit1254.txt    windows-1254    ANSI Turkish; Turkish (Windows)
bestfit1255.txt    windows-1255    ANSI Hebrew; Hebrew (Windows)
bestfit1256.txt    windows-1256    ANSI Arabic; Arabic (Windows)
bestfit1257.txt    windows-1257    ANSI Baltic; Baltic (Windows)
bestfit1258.txt    windows-1258    ANSI/OEM Vietnamese; Vietnamese (Windows)

These tables include "best fit" behavior which is not present in the other files. Examples of best fit
are converting fullwidth letters to their counterparts when converting to single byte code pages, and
mapping the Infinity character to the number 8.
 
932, 936, 949 and 950 are all double byte code pages. The remainder are single byte code pages. Each file
is encoded in the code page it describes, eg: bestfit1252.txt is encoded in the windows-1252 encoding. The only
non-ASCII characters however are in the comments so these files may be read by an ASCII parser if necessary.

Each file has sections of key word tags and records. Any text after a ; is ignored as are blank lines. Fields are
delimited by one or more space or tab characters. Each section begins one of the following tags:

CODEPAGE
CPINFO
MBTABLE
WCTABLE
DBCSRANGE  (double byte code pages only)
DBSCTABLE  (double byte code pages only)

Descriptions of each tag are:

CODEPAGE 932            ; Japanese - ANSI, OEM

  The CODEPAGE tag contains 1 field and marks the start of the code page file.

  Field 1 -- The only field is the decimal windows code page number for this code page.

CPINFO 2 0x3f 0x30fb    ; DBCS CP, Unic Default Char = Katakana Middle Dot

  The CPINFO tag describes the code page with 3 fields:

  Field 1 -- "1" for a single byte code page, "2" for a double byte code page.
  Field 2 -- Replacement characters for unassigned Unicode code points when written to this
  		code page (currently always ?)
  Field 3 -- Replacement characters for illegal or unassigned code page values when converting to Unicode.
  		This is Katakana middle dot for 932 and ? for all other code pages.

MBTABLE 256

  The MBTABLE tag marks the start of the "Multibyte" code page to Unicode conversion table. It has 1 field.
 
  Field 1 -- This field contains the number of following records of code page to Unicode mappings. Note that
  		lead bytes dont have mappings, so this is not always 256. For 932 for example it is 196.

MultiByte Mapping Records:

0x00	0x0000	;Null
0x01	0x0001	;Start Of Heading
...
0x30	0x0030	;Digit 0
0x31	0x0031	;Digit 1
...

Each record consists of two fields to map from the code page to Unicode.

  Field 1 -- The code page byte that is being mapped to Unicode, eg "0x3f"
  Field 2 -- The Unicode UTF-16 code point that this byte maps to, eg "0x003f"

DBCSRANGE  2            ;2 DBCS Lead Byte Ranges: 0x81-0x9f and 0xe0-0xfc

  The DBSCRANGE describes the number of double byte ranges for double byte code page. Ranges are consecutive
  	lead byte values such as 0x81-0x9f

  Field 1 -- This field contains the number of double byte ranges. The next record is the 1st lead byte range

0x81  0x9f              ;Lead Byte Range

This record describes the first lead byte range. It is the first record after DBCSRANGE and is followed by one
DBCSTABLE record for each lead byte in the range. If there are additional ranges, another Lead Byte Range record
will follow the last DBCSTABLE in the previous range.

  Field 1 -- This field is the first lead byte used in this range.

  Field 2 -- This field is the last lead byte used in this range

DBCSTABLE 147           ;LeadByte = 0x81

  The DBCSTABLE record describes the mappings available for a particular lead byte. The comment is ignored but
  	descriptive. The lead byte of the first DBCSTABLE is the first lead byte of the previous Lead Byte Range
	record. Each subsequent DBCSTABLE is for the next consecutive lead byte value.

  Field 1 -- This field is the number of trail byte mappings following.

Double byte mapping records:

0x40	0x3000	;   Ideographic Space
0x41	0x3001	;   Ideographic Comma
...

  Field 1 -- This field is the trail byte to map from.

  Field 2 -- This field is the Unicode UTF-16 code point that this lead byte/trail byte combination map to.

Example:

DBCSRANGE  2            ;2 DBCS Lead Byte Ranges: 0x81-0x9f and 0xe0-0xfc

0x81  0x9f              ;Lead Byte Range

DBCSTABLE 147           ;LeadByte = 0x81

0x40	0x3000	;   Ideographic Space
0x41	0x3001	;   Ideographic Comma
...

The preceeding example would map the byte sequences 0x81 0x40 to U+3000 and 0x81 0x41 to U+3001.


WCTABLE 698

  The WCTABLE tag marks the start of the Unicode UTF-16 (WideChar) to "MultiByte" bytes. It has 1 field.

  Field 1 -- This field contains the number of records of Unicode to byte mappings. Note that this is often
    more than the number of round trip mappings supported by the code page due to windows "Best Fit" behavior.

Unicode UTF-16 (WideChar) Mapping Records:

These take two forms, differing between single byte and double byte code pages. Both forms have 2 fields:

Single byte WCTABLE records:

0x0000	0x00	;Null
0x0001	0x01	;Start Of Heading
...
0x0061	0x61	;Latin Small Letter A
0x0062	0x62	;Latin Small Letter B
0x0063	0x63	;Latin Small Letter C
...
0x221e	0x38	;Infinity                        << Best Fit Mapping
...
0xff41	0x61	;Fullwidth Latin Small Letter A  << Best Fit Mapping
0xff42	0x62	;Fullwidth Latin Small Letter B  << Best Fit Mapping
0xff43	0x63	;Fullwidth Latin Small Letter C  << Best Fit Mapping
...

  Field 1 -- The Unicode UTF-16 code point for the character being converted.

  Field 2 -- The single byte that this UTF-16 code point maps to. If a reverse mapping does not in the MBTABLE,
  		then this is a Best Fit mapping.

Multibyte WCTABLE records:

0x0000	0x0000	;   Null
0x0001	0x0001	;   Start Of Heading
...
0x0061	0x0061	;   a
0x0062	0x0062	;   b
0x0063	0x0063	;   c
...
0x221e	0x8187	;   Infinity
...
0xff41	0x8281	;   Fullwidth a
0xff42	0x8282	;   Fullwidth b
0xff43	0x8283	;   Fullwidth c
...

  Field 1 -- The Unicode UTF-16 code point for the character being converted.

  Field 2 -- The byte or bytes that this code point maps to as a 16 bit value. The high byte is the lead byte,
    and the low byte is the trail byte. If the high byte is 0, then this is a single byte code point, with
    the value of the low byte and no lead byte is emitted.

ENDCODEPAGE

  This tag marks the end of the code page data. Anything after this marker is ignored.
