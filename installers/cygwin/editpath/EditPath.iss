; Copyright (C) 2021-2023 by Bill Stewart (bstewart at iname.com)
;
; This program is free software; you can redistribute it and/or modify it under
; the terms of the GNU Lesser General Public License as published by the Free
; Software Foundation; either version 3 of the License, or (at your option) any
; later version.
;
; This program is distributed in the hope that it will be useful, but WITHOUT
; ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
; FOR A PARTICULAR PURPOSE. See the GNU General Lesser Public License for more
; details.
;
; You should have received a copy of the GNU Lesser General Public License
; along with this program. If not, see https://www.gnu.org/licenses/.

; Sample Inno Setup (https://www.jrsoftware.org/isinfo.php) script
; demonstrating use of PathMgr.dll.
;
; This script uses PathMgr.dll in the following ways:
; * Copies PathMgr.dll to the target machine (required for uninstall)
; * Defines a task in [Tasks] that should modify the Path
; * Imports the AddDirToPath() DLL function at setup time
; * Imports the RemoveDirFromPath() DLL function at uninstall time
; * Stores task state as custom setting using RegisterPreviousData()
; * Retrieves task state custom setting during setup and uninstall initialize
; * At post install, adds app dir to Path if task selected
; * At uninstall, removes dir from Path if custom setting present
; * Unloads and deletes DLL and removes app dir at uninstall deinitialize

#if Ver < EncodeVer(6,0,0,0)
  #error This script requires Inno Setup 6 or later
#endif

[Setup]
AppId={{A17D2D05-C729-4F2A-9CC7-E04906C5A842}
AppName=EditPath
AppVersion=4.0.4.0
UsePreviousAppDir=false
DefaultDirName={autopf}\EditPath
Uninstallable=true
OutputDir=.
OutputBaseFilename=EditPath_Setup
ArchitecturesInstallIn64BitMode=x64
PrivilegesRequired=none
PrivilegesRequiredOverridesAllowed=dialog

[Files]
; Install PathMgr.dll for use with both setup and uninstall; use
; uninsneveruninstall flag because DeinitializeSetup() will delete after
; unloading the DLL; install the 32-bit version of PathMgr.dll because both
; setup and uninstall executables are 32-bit
Source: "i386\PathMgr.dll";  DestDir: "{app}"; Flags: uninsneveruninstall

; Other files to install on target system
Source: "i386\EditPath.exe";   DestDir: "{app}"; Check: not Is64BitInstallMode()
Source: "x86_64\EditPath.exe"; DestDir: "{app}"; Check: Is64BitInstallMode()
Source: "EditPath.md";         DestDir: "{app}"

[Tasks]
Name: modifypath; Description: "&Add to Path"

[Code]
const
  MODIFY_PATH_TASK_NAME = 'modifypath';  // Specify name of task

var
  PathIsModified: Boolean;          // Cache task selection from previous installs
  ApplicationUninstalled: Boolean;  // Has application been uninstalled?

// Import AddDirToPath() at setup time ('files:' prefix)
function DLLAddDirToPath(DirName: string; PathType, AddType: DWORD): DWORD;
  external 'AddDirToPath@files:PathMgr.dll stdcall setuponly';

// Import RemoveDirFromPath() at uninstall time ('{app}\' prefix)
function DLLRemoveDirFromPath(DirName: string; PathType: DWORD): DWORD;
  external 'RemoveDirFromPath@{app}\PathMgr.dll stdcall uninstallonly';

// Wrapper for AddDirToPath() DLL function
function AddDirToPath(const DirName: string): DWORD;
var
  PathType, AddType: DWORD;
begin
  // PathType = 0 - use system Path
  // PathType = 1 - use user Path
  // AddType = 0 - add to end of Path
  // AddType = 1 - add to beginning of Path
  if IsAdminInstallMode() then
    PathType := 0
  else
    PathType := 1;
  AddType := 0;
  result := DLLAddDirToPath(DirName, PathType, AddType);
end;

// Wrapper for RemoveDirFromPath() DLL function
function RemoveDirFromPath(const DirName: string): DWORD;
var
  PathType: DWORD;
begin
  // PathType = 0 - use system Path
  // PathType = 1 - use user Path
  if IsAdminInstallMode() then
    PathType := 0
  else
    PathType := 1;
  result := DLLRemoveDirFromPath(DirName, PathType);
end;

procedure RegisterPreviousData(PreviousDataKey: Integer);
begin
  // Store previous or current task selection as custom user setting
  if PathIsModified or WizardIsTaskSelected(MODIFY_PATH_TASK_NAME) then
    SetPreviousData(PreviousDataKey, MODIFY_PATH_TASK_NAME, 'true');
end;

function InitializeSetup(): Boolean;
begin
  result := true;
  // Was task selected during a previous install?
  PathIsModified := GetPreviousData(MODIFY_PATH_TASK_NAME, '') = 'true';
end;

function InitializeUninstall(): Boolean;
begin
  result := true;
  // Was task selected during a previous install?
  PathIsModified := GetPreviousData(MODIFY_PATH_TASK_NAME, '') = 'true';
  ApplicationUninstalled := false;
end;

procedure CurStepChanged(CurStep: TSetupStep);
begin
  if CurStep = ssPostInstall then
  begin
    // Add app directory to Path at post-install step if task selected
    if PathIsModified or WizardIsTaskSelected(MODIFY_PATH_TASK_NAME) then
      AddDirToPath(ExpandConstant('{app}'));
  end;
end;

procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    // Remove app directory from path during uninstall if task was selected;
    // use variable because we can't use WizardIsTaskSelected() at uninstall
    if PathIsModified then
      RemoveDirFromPath(ExpandConstant('{app}'));
  end
  else if CurUninstallStep = usPostUninstall then
  begin
    ApplicationUninstalled := true;
  end;
end;

procedure DeinitializeUninstall();
begin
  if ApplicationUninstalled then
  begin
    // Unload and delete PathMgr.dll and remove app dir when uninstalling
    UnloadDLL(ExpandConstant('{app}\PathMgr.dll'));
    DeleteFile(ExpandConstant('{app}\PathMgr.dll'));
    RemoveDir(ExpandConstant('{app}'));
  end;
end;
