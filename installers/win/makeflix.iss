; -- makeflix.iss --
; fgh 2016-08-19

#define x86_or_x64 "x86"
#define version "1.0.1"

#if x86_or_x64 == "x86" 
#define exe_dir "Win32"
#else
#define exe_dir "x64"
#endif

[Setup]
ArchitecturesAllowed={#x86_or_x64}
AppName=Makeflix
AppVersion={#version}
AppPublisher=Lellan, Inc.
AppPublisherURL=http://www.lellan.com/
AppCopyright=Copyright (C) 2012-2017 Lellan, Inc.
DefaultDirName={pf}\Lellan\Makeflix
DefaultGroupName=Lellan
UninstallDisplayIcon={app}\makeflix.exe
Compression=lzma2
SolidCompression=yes
; "ArchitecturesInstallIn64BitMode=x64" requests that the install be
; done in "64-bit mode" on x64, meaning it should use the native
; 64-bit Program Files directory and the 64-bit view of the registry.
ArchitecturesInstallIn64BitMode=x64
; Source Dir is lellan/toolchain/makeflix/windows
SourceDir="..\"
OutputDir="deploy"
OutputBaseFilename="makeflix_v{#version}_{#x86_or_x64}"
SetupIconFile="..\images\Lellan_Logo_20130221.ico"
LicenseFile="..\deploy\EULA.rtf"
DisableWelcomePage=no

[Files]
Source: "makeflix\{#exe_dir}\Release\makeflix.exe"; DestDir: "{app}"; DestName: "makeflix.exe"; Flags: ignoreversion
Source: "deploy\DLLs\{#x86_or_x64}\Qt5Core.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "deploy\DLLs\{#x86_or_x64}\Qt5Gui.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "deploy\DLLs\{#x86_or_x64}\Qt5Widgets.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "deploy\DLLs\{#x86_or_x64}\Qt5Network.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "deploy\DLLs\{#x86_or_x64}\platforms\qwindows.dll"; DestDir: "{app}\platforms"; Flags: ignoreversion
Source: "deploy\gstreamer\{#x86_or_x64}\*"; DestDir: "{app}\gstreamer"; Flags: recursesubdirs ignoreversion
Source: "deploy\vc_redist\vc_redist.{#x86_or_x64}.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall 
Source: "deploy\bonjour\Bonjour.{#x86_or_x64}.msi"; DestDir: "{tmp}" ; Flags: deleteafterinstall

Source: "..\deploy\Makeflix_Open_Source_Libraries.pdf"; DestDir: "{app}"

[Icons]
Name: "{group}\Makeflix"; Filename: "{app}\makeflix.exe"
Name: "{group}\Uninstall Makeflix"; Filename: "{uninstallexe}"


[Run]
#define VCmsg "Installing Microsoft Visual C++ Redistributable ..."
Filename: "{tmp}\vc_redist{#x86_or_x64}.exe"; StatusMsg: "{#VCmsg}"; Check: not VCinstalled
#define BonjourMsg "Installing Apple Bonjour support ..."
Filename: "msiexec"; Parameters: "/i {tmp}\Bonjour.{#x86_or_x64}.msi"; StatusMsg: "{#BonjourMsg}"; Check: not BonjourInstalled

[Registry]
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\makeflix.exe"; ValueType: string; ValueName: "(Default)"; ValueData: "{app}\makeflix.exe"; Flags: uninsdeletekey
Root: HKLM; Subkey: "SOFTWARE\Microsoft\Windows\CurrentVersion\App Paths\makeflix.exe"; ValueType: string; ValueName: "Path"; ValueData: "{app}\gstreamer\bin"; Flags: uninsdeletekey

[Code]
function VCinstalled: Boolean;
 // By Michael Weiner <mailto:spam@cogit.net>
 // Function for Inno Setup Compiler
 // 13 November 2015
 // Modified by Frank G Halasz to handle WOW case
 // 23 August 2016
 // Returns True if Microsoft Visual C++ Redistributable is installed, otherwise False.
 // The programmer may set the year of redistributable to find; see below.
 var
  names: TArrayOfString;
  i: Integer;
  dName, key, year, platfm: String;
 begin
  // Year of redistributable to find; leave null to find installation for any year.
  year := '2015';
  Result := False;
  if Is64BitInstallMode then
    begin
      platfm := 'x64'; 
      key := 'Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall';
    end
  else if not IsWin64 then
    begin
      platfm := 'x86';
      key := 'Software\Microsoft\Windows\CurrentVersion\Uninstall';
    end
  else
    begin
      platfm := 'x86';
      key := 'Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall';
    end;
  // Get an array of all of the uninstall subkey names.
  if RegGetSubkeyNames(HKEY_LOCAL_MACHINE, key, names) then
   // Uninstall subkey names were found.
   begin
    i := 0
    while ((i < GetArrayLength(names)) and (Result = False)) do
     // The loop will end as soon as one instance of a Visual C++ redistributable is found.
     begin
      // For each uninstall subkey, look for a DisplayName value.
      // If not found, then the subkey name will be used instead.
      if not RegQueryStringValue(HKEY_LOCAL_MACHINE, key + '\' + names[i], 'DisplayName', dName) then
       dName := names[i];
      // See if the value contains both of the strings below.
      Result := (Pos(Trim('Visual C++ ' + year),dName) * Pos('Redistributable',dName) * Pos(platfm, dName) <> 0)
      i := i + 1;
     end;
   end;
 end;

 function BonjourInstalled: Boolean;
 // Returns True if Apple Bonjour is installed, otherwise False.
 // Ignores date/version of Bonjour.
 begin
  Result := False;
  // If this key exists, then
  // bonjour services must already be installed
  if RegKeyExists(HKEY_LOCAL_MACHINE, 'SYSTEM\CurrentControlSet\Services\Bonjour Service') then
   // Uninstall subkey names were found.
   begin
     Result := True;
   end;
 end;
