;###############################################################################
;#
;#    medley.iss - Inno Setup compiler script for creating a Windows
;#                 installer for cygwin and Medley on cygwin
;#
;#   2023-06-03 Frank Halasz
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
DefaultDirName={%USERPROFILE}\il
DefaultGroupName=Medley
Compression=lzma2
SolidCompression=yes
; "ArchitecturesInstallIn64BitMode=x64" requests that the install be
; done in "64-bit mode" on x64, meaning it should use the native
; 64-bit Program Files directory and the 64-bit view of the registry.
ArchitecturesInstallIn64BitMode=x64
OutputDir="."
OutputBaseFilename="medley-full-{#version}-cygwin-x86_64"
SetupIconFile="Medley.ico"
DisableWelcomePage=no
MissingRunOnceIdsWarning=no
DisableProgramGroupPage=yes
WizardImageFile=medley_logo.bmp
WizardSmallImageFile=medley_logo_small.bmp
WizardImageStretch=no
UninstallDisplayIcon="{app}\Medley.ico"
UninstallFilesDir={app}\uninstall
UsePreviousAppDir=no

[Dirs]
Name: "{app}\install"; Permissions: everyone-full
Name: "{app}\uninstall"; Permissions: everyone-full
Name: "{app}\cygwin"; Permissions: everyone-full

[Files]
Source: "setup-x86_64.exe"; DestDir: "{app}\cygwin"; DestName: "setup-x86_64.exe"; Flags: ignoreversion
Source: "maiko-cygwin.x86_64.tgz"; DestDir: "{app}\install"; DestName: "maiko-cygwin.x86_64.tgz"; Flags: ignoreversion
Source: "medley.tgz"; DestDir: "{app}\install"; DestName: "medley.tgz"; Flags: ignoreversion
Source: "make_medley-bat.sh"; DestDir: "{app}\install"; DestName: "make_medley-bat.sh"; Flags: ignoreversion
Source: "..\win\editpath\x86_64\EditPath.exe"; DestDir: "{app}\uninstall"; DestName: "EditPath.exe"; Flags: ignoreversion
Source: "Medley.ico"; DestDir: "{app}"; DestName: "Medley.ico"; Flags: ignoreversion

[Icons]
Name: "{group}\Medley\Uninstall_Medley"; Filename: "{uninstallexe}"
; Name: "{group}\Medley\Medley"; Filename: "powershell"; Parameters: "-NoExit -File {app}\medley.ps1 --help"; IconFilename: "{app}\Medley.ico"

[Run]
Filename: "{app}\cygwin\setup-x86_64.exe"; Parameters: "--quiet-mode --no-admin --wait --no-shortcuts --no-write-registry --verbose --root {app} --site http://www.gtlib.gatech.edu/pub/cygwin/ --only-site --local-package-dir {app}\cygwin --packages nano,xdg-utils"
Filename: "{app}\bin\bash"; Parameters: "-login -c 'sed -i -e s/^none/#none/ /etc/fstab && echo none / cygdrive binary,posix=0,user 0 0 >>/etc/fstab'"; Flags: runhidden
Filename: "{app}\bin\bash"; Parameters: "-login -c 'tar -x -z -C / -f /install/medley.tgz'"; Flags: runhidden; StatusMsg: "Installing Medley ..."
Filename: "{app}\bin\bash"; Parameters: "-login -c 'rm -rf /maiko'"; Flags: runhidden; StatusMsg: "Installing Maiko ..."
Filename: "{app}\bin\bash"; Parameters: "-login -c 'tar -x -z -C / -f /install/maiko-cygwin.x86_64.tgz'"; Flags: runhidden; StatusMsg: "Installing Maiko ..."
Filename: "{app}\bin\bash"; Parameters: "-login /install/make_medley-bat.sh"; WorkingDir: "{app}"; Flags: runhidden; StatusMsg: "Installing medley.bat ..."
Filename: "{app}\uninstall\EditPath.exe"; Parameters: "--user --add {app}"; Flags: runhidden; StatusMsg: "Adding to PATH ..."
Filename: "{app}\bin\bash"; Parameters: "-login -c 'rm -rf /install'"; Flags: runhidden; StatusMsg: "Cleaning up ..."

[UninstallRun]
Filename: "{app}\uninstall\EditPath.exe"; Parameters: "--user --remove {app}"; Flags: runhidden 

