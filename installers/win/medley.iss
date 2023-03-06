;###############################################################################
;#
;#    medley.iss - Inno Setup compiler script for creating a Windows
;#                 installer for the medley.ps1 powrshell script for
;#                 running Medley within a docker container on Windows
;#
;#   2023-02-12 Frank Halasz
;#
;#   Copyright 2023 Interlisp.org
;#
;###############################################################################

#define x86_or_x64 "x64"
#if GetEnv('COMBINED_RELEASE_TAG') != ""
#define VERSION=GetEnv('COMBINED_RELEASE_TAG')
#else
#define VERSION="local"
#endif

[Setup]
PrivilegesRequired=lowest
ArchitecturesAllowed={#x86_or_x64}
AppName=Medley
AppVersion={#version}
AppPublisher=Interlisp.org
AppPublisherURL=https://interlisp.org/
AppCopyright=Copyright (C) 2023 Interlisp.org
DefaultDirName={localappdata}\Medley\Scripts
DefaultGroupName=Medley
Compression=lzma2
SolidCompression=yes
; "ArchitecturesInstallIn64BitMode=x64" requests that the install be
; done in "64-bit mode" on x64, meaning it should use the native
; 64-bit Program Files directory and the 64-bit view of the registry.
ArchitecturesInstallIn64BitMode=x64
OutputDir="."
OutputBaseFilename="medley-full-{#version}-windows-{#x86_or_x64}"
SetupIconFile="Medley.ico"
DisableWelcomePage=no
MissingRunOnceIdsWarning=no
DisableProgramGroupPage=yes
WizardImageFile=medley_logo.bmp
WizardSmallImageFile=medley_logo_small.bmp
WizardImageStretch=no
UninstallDisplayIcon="{app}\Medley.ico"



[Files]
Source: "..\..\scripts\medley\medley.ps1"; DestDir: "{app}"; DestName: "medley.ps1"; Flags: ignoreversion
Source: "..\..\scripts\medley\medley.cmd"; DestDir: "{app}"; DestName: "medley.cmd"; Flags: ignoreversion
Source: "editpath\x86_64\EditPath.exe"; DestDir: "{app}"; DestName: "EditPath.exe"; Flags: ignoreversion
Source: "Medley.ico"; DestDir: "{app}"; DestName: "Medley.ico"; Flags: ignoreversion
Source: "vncviewer64-1.12.0.exe"; DestDir: "{app}"; DestName: "vncviewer64-1.12.0.exe"; Flags: ignoreversion
[Icons]
Name: "{group}\Medley\Uninstall_Medley"; Filename: "{uninstallexe}"
Name: "{group}\Medley\Medley"; Filename: "powershell"; Parameters: "-NoExit -File {app}\medley.ps1 --help"; IconFilename: "{app}\Medley.ico"


[Run]
Filename: "{app}\EditPath.exe"; Parameters: "--user --add {app}"; Flags: runhidden

[UninstallRun]
Filename: "{app}\EditPath.exe"; Parameters: "--user --remove {app}"; Flags: runhidden 

