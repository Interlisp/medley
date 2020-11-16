The following is a listing of the differences between IBM's mappings
of certain IBM code pages and Unicode, and the mappings for IBM code
pages that came from various sources and were earlier made available
at the Unicode ftp site.

The first set of differences refers to tables found originally in the
Microsoft directory at unicode.org.  The DBCS tables were in the
EastAsiaMaps directory. The findings are based on the content of the
files as of April 26, 1996. Newer versions may result in fewer
differences.

Note that IBM has many conversion tables to Unicode available in a
binary (machine readable) format on a CD-ROM included with the
document SC09-2190-00 "CDRA Reference and Registry".  These tables
are also available in a readable format from IBM.  For licensing
information, please contact an IBM representative to the Unicode
council.  Currently (March/96) these are:

  Dr. V.S. (Uma) Umamaheswaran   dorai@vnet.ibm.com
  John Gioia                     gioia@vnet.ibm.com
  Lisa Moore                     lisam@vnet.ibm.com

Or, you may send a note to nltc@vnet.ibm.com.

=======================================================================
Code Pages 00437 (US etc.)
           00860 (Portugal)
           00861 (Iceland)
           00862 (Israel)
           00863 (Canadian French)
           00865 (Nordic)

      Microsoft                         IBM
      ---------                       -----
0x1A      U001A                       U001C
0x1C      U001C                       U007F
0x7F      U007F                       U001A
0xE6      U00B5 (MICRO SIGN)          U03BC (GREEK SMALL LETTER MU)

The "rotation" of the control characters at 0x1A, 0x1C and
0x7F is due to the frequent use of 0x1A as end-of-file by
PC file systems and applications.

=======================================================================
Code Page 00852

          Microsoft                         IBM
          ---------                       -----
0x1A      U001A                       U001C
0x1C      U001C                       U007F
0x7F      U007F                       U001A
0xAA      U00AC (NOT SIGN)             ----  (Unassigned)

Note that Microsoft code page 852 has a "not sign" in position 0xAA
whereas IBM 852 has 0xAA as unassigned.  In IBM mappings, unassigned
code points in a code page are generally mapped to SUB (U001A) in the
binary tables.  The readable tables do not contain entries for these
points.

=======================================================================
Code Page 00850 (Latin 1)
          00855 (Cyrillic)
          00866 (Cyrillic - Russian)

      Microsoft                         IBM
      ---------                       -----
0x1A      U001A                       U001C
0x1C      U001C                       U007F
0x7F      U007F                       U001A


=======================================================================
Code Page 00857 (Turkish)

      Microsoft                         IBM
      ---------                       -----
0x1A      U001A                       U001C
0x1C      U001C                       U007F
0x7F      U007F                       U001A


=======================================================================
Code Page 00864 (Arabic)

      Microsoft                         IBM
      ---------                       -----
0x1A      U001A                       U001C
0x1C      U001C                       U007F
0x7F      U007F                       U001A
0x9B      U009B                        ----  (Unassigned)
0x9C      U009C                        ----  (Unassigned)
0x9F      U009F                       U200C  (ZERO WIDTH NON-JOINER)
0xA6      UF8BE                        ----  (Unassigned)
0xA7      UF8BF                        ----  (Unassigned)
0xD7      UFEC1 (ISOLATE ARABIC TAH)  UFEC3  (MEDIAL ARABIC TAH)
0xD8      UFEC5 (ISOLATE ARABIC DHAH) UFEC7  (MEDIAL ARABIC DHAH)
0xF1      U0651 (ARABIC SHADDAH)      UFE7C  (ARABIC SPACING SHADDAH)


=======================================================================
Code Page 00869 (Greek)

      Microsoft                         IBM
      ---------                       -----
0x1A      U001A                       U001C
0x1C      U001C                       U007F
0x7F      U007F                       U001A
0x80      U0080                        ----  (Unassigned)
0x81      U0081                        ----  (Unassigned)
0x82      U0082                        ----  (Unassigned)
0x83      U0083                        ----  (Unassigned)
0x84      U0084                        ----  (Unassigned)
0x85      U0085                        ----  (Unassigned)
0x87      U0087                        ----  (Unassigned)
0x88      U00B7 (MIDDLE DOT)          U0387  (GREEK ANO TELEIA)
0x93      U0093                        ----  (Unassigned)
0x94      U0094                        ----  (Unassigned)
0xEF      U0384 (GREEK TONOS)         U00B4  (ACUTE ACCENT)


=======================================================================
Code Page 00874 (Thai)

      Microsoft                         IBM
      ---------                       -----
0x1A      U001A                       U001C
0x1C      U001C                       U007F
0x7F      U007F                       U001A
0x91      U2018                        ----  (Unassigned)
0x92      U2019                        ----  (Unassigned)
0x93      U201C                        ----  (Unassigned)
0x94      U201D                        ----  (Unassigned)
0x95      U2022                        ----  (Unassigned)
0x96      U2013                        ----  (Unassigned)
0x97      U2014                        ----  (Unassigned)
0xA0      U00A0                       U0E48  (THAI CHARACTER MAI EK)
0xDB       ----  (Unassigned)         U0E49  (THAI CHARACTER MAI THO)
0xDC       ----  (Unassigned)         U0E4A  (THAI CHARACTER MAI TRI)
0xDD       ----  (Unassigned)         U0E4B  (THAI CHARACTER MAI CHATTAW)
0xDE       ----  (Unassigned)         U0E4C  (THAI CHARACTER THANTHAKHAT)
0xFC       ----  (Unassigned)         U00A2  (CENT SIGN)
0xFD       ----  (Unassigned)         U00AC  (NOT SIGN)
0xFE       ----  (Unassigned)         U00A6  (BROKEN BAR)
0xFF       ----  (Unassigned)         U00A0  (NO-BREAK SPACE)


=======================================================================

Regarding the mapping table between Unicode and Asian each country's
National Standard, there are several differences between the tables in
this directory and the table developed by IBM.
The following list shows these differences.
=======================================================================
Japanese (JIS X0208)

            Unicode                       IBM
            -------                       -----
(1) 0x213D  U2015                         U2014

Note:
 (1) According to conversion table defined on JIS X0221 (ISO 10646-1
     JIS version), JIS:0x213D is mapped to U2014.
=======================================================================
S-Chinese (GB 2312)

            Unicode                       IBM
            -------                       -----
(1) 0x212C  U2225                         U2016
(2) 0x2327  UFF07                         U00B4

Note:
 (1) According to GB2312-80 standard, the character name of
     GB2312:0x212C is Double Vertical Line. And, U2016 is
     Double Vertical Line.
 (2) The character name of GB2312:0x2327 is Single Quotation
     Mark Right. Though no same character name exists in Unicode,
     glyph of U00B4 looks similar than UFF07.

=======================================================================

Please note that it is IBM policy to create a new code page identifier
when there are any changes (other than additions) to a code page.
This allows data or environment tagged with a specific identifier to
have a precise meaning even after many years, and allows migration of
environments (resources such as keyboard drivers, fonts etc..) to be
managed in an orderly manner.  This may result in a mismatch between
an IBM identifier and the same identifier used by another vendor if
that other vendor has modified the contents of the code page without
changing the identifier.

Current known cases of a code page not matching the IBM code page using
the same identifier include:

  Microsoft 932 (Japanese)
  Microsoft 936 (Simplified Chinese)
  Microsoft 949 (Korean)
  Microsoft 852 (See above)
