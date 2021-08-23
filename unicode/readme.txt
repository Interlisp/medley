This Unicode directory contains mapping files extracted from the CDROM that came with the Unicode 3.0 book (2000).

The Xerox subdirectory contains mappings from the Xerox character encoding (version XC1-3-3-0, 1887) into Unicode 3.0.   standard into Unicode.  That is the version of XCCS corresponding to the fonts in the Medley system.  The Xerox mappings did not come from the Unicode CDROM, they were constructed by combining and constrasting information from a binary file (xerox>XCCStoUni) of unknown provenance with code mappings scraped from the Wikipedia page https://en.wikipedia.org/wiki/Xerox_Character_Code_Standard in July 2020.  Both sources were errorful and incomplete, so many of the mappings were hand corrected.  There are still missing mappings, and there still may be errors.

EASTASIA:
	The CDROM came with CJK cross reference mappings for standards such as KSC5601,
	GB2312, JIS0208, etc. to Unicode 2.0.
	However, these particular mappings are now obsolete and have been removed as per
	this note from Unicode.org:
	   The entire former contents of this directory are obsolete and have been
       moved to the OBSOLETE directory.  The latest information may be found
       in the Unihan data files in the latest Unicode Character Database.
       August 1, 2001.
    The current set of mappings are available from 
           https://unicode.org/Public/UNIDATA/Unihan.zip
    The format of these files is given in https://unicode.org/reports/tr38/
 
ISO8859:
	These are the mapping tables of the ISO 8859 series (1 through 16)

VENDORS:
	Miscellaneous mapping tables for small codesets, typically provided
	by vendors.

TCVN:
	Chu Nom mapping & database.


Always consult www.unicode.org for updates and changes to these files.
