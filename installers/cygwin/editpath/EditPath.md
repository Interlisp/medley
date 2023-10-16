# EditPath

EditPath is a Windows console (text-based, command-line) program for managing the system Path and user Path.

# Author

Bill Stewart - bstewart at iname dot com

# License

EditPath.exe is covered by the GNU Lesser Public License (LPGL). See the file `LICENSE` for details.

# Download

https://github.com/Bill-Stewart/PathMgr/releases/

# Background

The system Path is found in the following location in the Windows registry:

Root: `HKEY_LOCAL_MACHINE`  
Subkey: `SYSTEM\CurrentControlSet\Control\Session Manager\Environment`  
Value name: `Path`

The current user Path is found in the following location in the registry:

Root: `HKEY_CURRENT_USER`  
Subkey: `Environment`  
Value name: `Path`

In both cases, the `Path` value is (or should be) the registry type `REG_EXPAND_SZ`, which means that it is a string that can contain values surrounded by `%` characters that Windows will automatically expand to environment variable values. (For example, `%SystemRoot%` will be expanded to `C:\Windows` on most systems.)

The `Path` value contains a `;`-delimited list of directory names that the system should search for executables, library files, scripts, etc. Windows appends the content of the current user Path to the system Path and expands the environment variable references. The resulting string is set as the `Path` environment variable for processes.

EditPath provides a command-line interface for managing the `Path` value in the system location (in `HKEY_LOCAL_MACHINE`) and the current user location (in `HKEY_CURRENT_USER`).

# Usage

The following describes the command-line usage for the program. Parameters are case-sensitive.

**EditPath** [_options_] _type_ _action_

You must specify only one of the following _type_ parameters:

| _type_       | Abbreviation | Description
| -------      | ------------ | -----------
| **--system** | **-s**       | Specifies the system Path
| **--user**   | **-u**       | Specifies the user Path

You must specify only one of the following _action_ parameters:

| _action_                     | Abbreviation           | Description
| --------                     | ------------           | -----------
| **--list**                   | **-l**                 | Lists directories in Path
| **--test "**_dirname_**"**   | **-t "**_dirname_**"** | Tests if directory exists in Path
| **--add "**_dirname_**"**    | **-a "**_dirname_**"** | Adds directory to Path
| **--remove "**_dirname_**"** | **-r "**_dirname_**"** | Removes directory from Path

The following parameters are optional:

| _options_       | Abbreviation | Description
| ---------       | ------------ | -----------
| **--quiet**     | **-q**       | Suppresses result messages
| **--expand**    | **-x**       | Expands environment variables (**--list** only)
| **--beginning** | **-b**       | Adds to beginning of Path (**--add** only)

# Exit Codes

The following table lists typical exit codes when not using **--test** (**-t**).

| Exit Code | Description
| --------- | -----------
| 0         | No errors
| 2         | The Path value is not present in the registry
| 3         | The specified directory does not exist in the Path
| 5         | Access is denied
| 87        | Incorrect parameter(s)
| 183       | The specified directory already exists in the Path

The following table lists typical exit codes when using **--test** (**-t**).

| Exit Code | Description
| --------- | -----------
| 1         | The specified directory exists in the unexpanded Path
| 2         | The specified directory exists in the expanded Path
| 3         | The specified directory does not exist in the Path

# Remarks

* Anything on the command line after **--test**, **--add**, or **--remove** is considered to be the argument for the parameter. To avoid ambiguity, specify the _action_ parameter last on the command line.

* Uexpanded vs. expanded refers to whether the environment variable references (i.e., names between `%` characters) are expanded after retrieving the Path value from the registry. For example, `%SystemRoot%` is unexpanded but `C:\Windows` is expanded.

* The **--add** (**-a**) parameter checks whether the specified directory exists in both the unexpanded and expanded copies of the Path before adding the directory. For example, if the environment variable `TESTAPP` is set to `C:\TestApp` and `%TESTAPP%` is in the Path, specifying `--add C:\TestApp` will return exit code 183 (i.e., the directory already exists in the Path) because `%TESTAPP%` expands to `C:\TestApp`.

* The **--remove** (**-r**) parameter does not expand environment variable references. For example, if the environment variable `TESTAPP` is set to `C:\TestApp` and `%TESTAPP%` is in the Path, specifying `--remove "C:\TestApp"` will return exit code 3 (i.e., the directory does not exist in the Path) because **--remove** does not expand `%TESTAPP%` to `C:\TestApp`. For the command to succeed, you would have to specify `--remove "%TESTAPP%"` instead.

* The program will exit with error code 87 if a parameter (or an argument to a parameter) is missing or not valid, if mutually exclusive parameters are specified, etc.

* The program will exit with error code 5 if the current user does not have permission to update the Path value in the registry (for example, if you try to update the system Path using a standard user account or an unelevated administrator account).

# Examples

1.  `EditPath --expand --system --list`

    This command outputs the directories in the system Path, with environment variables expanded. You can also write this command as `EditPath -x -s -l`.

2.  `EditPath --user --add "%LOCALAPPDATA%\Programs\MyApp"`

    Adds the specified directory name to the user Path.

3.  `EditPath -s -r "C:\Program Files\MyApp\bin"`

    Removes the specified directory from the system Path.

4.  `EditPath -s --test "C:\Program Files (x86)\MyApp\bin"`

    Returns an exit code of 3 if the specified directory is not in the system Path, 1 if the specified directory is in the unexpanded copy of the system Path, or 2 if the specified directory is in the expanded copy of the system Path.
