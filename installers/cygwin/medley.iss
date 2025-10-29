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

#if GetEnv('COMBINED_RELEASE_TAG') != ""
#define VERSION=GetEnv('COMBINED_RELEASE_TAG')
#else
#define VERSION="local"
#endif

#if GetEnv('CYGWIN_INSTALLER_BASE') != ""
#define OUTFILE=GetEnv('CYGWIN_INSTALLER_BASE')
#else
#define OUTFILE="medley-full-cygwin-x86_64-local"
#endif

[Setup]
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
AppName=Medley
AppVersion={#version}
AppPublisher=Interlisp.org
AppPublisherURL=https://interlisp.org/
AppCopyright=Copyright (C) 2023-2024 Interlisp.org
DefaultDirName="{%USERPROFILE}\il"
DefaultGroupName=Medley
Compression=lzma2
SolidCompression=yes
OutputDir="."
OutputBaseFilename={#OUTFILE}
SetupIconFile="Medley.ico"
DisableWelcomePage=no
MissingRunOnceIdsWarning=no
DisableProgramGroupPage=yes
WizardImageFile=medley_logo.bmp
WizardSmallImageFile=medley_logo_small.bmp
WizardImageStretch=no
UninstallDisplayIcon="{app}\Medley.ico"
UninstallFilesDir="{app}\uninstall"
UsePreviousAppDir=no

[Dirs]
Name: "{app}\install"; Permissions: everyone-full
Name: "{app}\uninstall"; Permissions: everyone-full
Name: "{app}\cygwin"; Permissions: everyone-full

[Files]
Source: "setup-x86_64.exe"; DestDir: "{app}\cygwin"; DestName: "setup-x86_64.exe"; Flags: ignoreversion
Source: "maiko-cygwin.x86_64.tgz"; DestDir: "{app}\install"; DestName: "maiko-cygwin.x86_64.tgz"; Flags: ignoreversion
Source: "medley.tgz"; DestDir: "{app}\install"; DestName: "medley.tgz"; Flags: ignoreversion
Source: "..\win\editpath\x86_64\EditPath.exe"; DestDir: "{app}\uninstall"; DestName: "EditPath.exe"; Flags: ignoreversion
Source: "Medley.ico"; DestDir: "{app}"; DestName: "Medley.ico"; Flags: ignoreversion

[Icons]
Name: "{group}\Medley\Uninstall_Medley"; Filename: "{uninstallexe}"
; Name: "{group}\Medley\Medley"; Filename: "powershell"; Parameters: "-NoExit -File {app}\medley.ps1 --help"; IconFilename: "{app}\Medley.ico"

[Run]
Filename: "{app}\cygwin\setup-x86_64.exe"; Parameters: "--quiet-mode --no-admin --wait --no-shortcuts --no-write-registry --verbose --root ""{app}"" --site https://mirrors.kernel.org/sourceware/cygwin --only-site --local-package-dir ""{app}\cygwin"" --packages nano,xdg-utils,ghostscript,ghostscript-fonts-other"; StatusMsg: "Installing Cygwin ..."
Filename: "{app}\bin\bash"; Parameters: "-login -c 'sed -i -e s/^none/#none/ /etc/fstab && echo none / cygdrive binary,posix=0,user 0 0 >>/etc/fstab'"; Flags: runhidden
Filename: "tar"; Parameters: "-x -z -C ""{app}"" -f ""{app}\install\medley.tgz"""; Flags: runhidden; StatusMsg: "Installing Medley ..."
Filename: "powershell"; Parameters: "remove-item -force -recurse ""{app}\maiko"""; Flags: runhidden; StatusMsg: "Installing Maiko ..."
Filename: "tar"; Parameters: "-x -z -C ""{app}"" -f ""{app}\install\maiko-cygwin.x86_64.tgz"""; Flags: runhidden; StatusMsg: "Installing Maiko ..."
; Recreate medley symbolic links (lost in tars)
Filename: "{app}\bin\bash"; Parameters: "-login -c 'cd /medley/scripts/medley && ln -s medley.command medley.sh && cd ../.. && ln -s /medley/scripts/medley/medley.sh medley'"; Flags: runhidden
; Create medley.bat
Filename: "powershell"; Parameters: "write-output '""""""""{app}\bin\bash"""""""" -login -c """"""""/medley/scripts/medley/medley.sh %*""""""""'  | out-file medley.bat -Encoding ascii -NoNewline"; WorkingDir: "{app}"; Flags: runhidden; StatusMsg: "Creating medley.bat ..."
Filename: "{app}\uninstall\EditPath.exe"; Parameters: "--user --add ""{app}"""; Flags: runhidden; StatusMsg: "Adding to PATH ..."
Filename: "powershell"; Parameters: "remove-item -recurse -force """"""""{app}\install"""""""""; Flags: runhidden; StatusMsg: "Cleaning up ..."

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[UninstallRun]
Filename: "{app}\uninstall\EditPath.exe"; Parameters: "--user --remove ""{app}"""; Flags: runhidden 

