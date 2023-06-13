###############################################################################
#
#    medley.ps1 - PowerShell script for running Medley Interlisp in a Docker
#                 container on Windows. This script will pull the
#                 interlisp/medley docker container, run the container
#                 using the Linux medley script as the entrypoint
#                 passing on the flags as given to this script, and
#                 then start a vncviewer onto medley running in the 
#                 container.
#
#                 This script can also be used to start medley in a WSL
#                 distro, although the same can easily be accomplished
#                 using the wsl command.
#
#   2023-02-10 Frank Halasz
#
#   Copyright 2023 Interlisp.org
#
###############################################################################


#
#  Various useful functions
#

# Function to check if docker is installed on this system
function Test-DockerInstalled {
    $ErrorActionPreference = "SilentlyContinue" 
    if (Get-Command "docker" -Syntax)
        { return $true }
    else
        { return $false }
}

# Function to check if docker is running on this system
function Test-DockerRunning {
    $ErrorActionPreference = "SilentlyContinue"
    docker info 2>&1 >$null 
    if ( $LastExitCode -eq 0 )
      { return $true }
    else
      { return $false }
}

# Function to test if WSL is installed on this machine
function Test-WSLInstalled {
    #$ErrorActionPreference = "SilentlyContinue" 
    if ((Get-Command "wsl" -Syntax) -and 
        (((wsl --list --verbose) -replace "`0" | Measure-Object -Line | Select -ExpandProperty Lines) -gt 1))
        { return $true }
    else
        { return $false }

}

# Function to test if a named WSL distro is actually present
function Test-WSLDistro {
    param($distro="unknown")
    $paddedDistro= " " + $distro + " "
    if ( (wsl --list --verbose) -replace "`0" | Select-String -Pattern $paddedDistro )
        { return $true }
    else
        { return $false }
}

# Function to test if medley is installed (using standard installation)
# in the wsl distro whose name is the first and only arg. Defaults
# to the default wsl distro
function Test-MedleyInstalled {
  param($distro)
  if($distro -and (-not (Test-WSLDistro $distro)))
    { 
      return $false
    }
  if ($distro)
    {
      $is_installed = wsl -d $distro bash -c "test -e /usr/local/interlisp; echo \`$?"
    }
  else
    {
      $is_installed = wsl bash -c "test -e /usr/local/interlisp; echo \`$?"
    }
  if ($is_installed -eq 0)
    {
      return $true
    }
  else 
    {
      return $false
    }
}

# Function to find an unused port between 5900 and 5999
function Find-OpenPort {
  $min_port=5900
  $max_port=5999
  $udp_openPorts = Get-NetUDPEndpoint | Where-Object { ($_.LocalPort -ge $min_port) -and ($_.LocalPort -le $max_port) }
  $tcp_openPorts = Get-NetTCPConnection | Where-Object { ($_.LocalPort -ge $min_port) -and ($_.LocalPort -le $max_port) }
  $openPorts = ($udp_openPorts + $tcp_openPorts) | Select-Object -Property LocalPort | Sort-Object -Property LocalPort -Unique
  $expected=$min_port;
  foreach ($port in $openPorts)
    {
      if ( $port.LocalPort -ne $expected )
        {
          break;
        }
      else
        {
          ${expected}++
        }
    }
  if ($expected -gt $max_port)
    {
      Write-Output "Error: No available ports between 5900 and 5999."
      Write-Output "Exiting."
      exit 34
    }
  else
    {
      return $expected
    }
}


#
#  Function that processes all the arguments to this script
#
function Process-Args {

  # Default values for script-scoped varaibles
  $script:bg = $false
  $script:draft = "latest"
  $script:logindir = "${env:USERPROFILE}\AppData\Local\Medley\il"
  $script:medleyArgs = @()
  $script:noviewer = $false
  $script:port = $false
  $script:update = $false
  $script:wsl = $false
  $displayFlag = $false
  $display = ""

  # Variables local this function
  $passRest = $false
  $vncRequested = $false

  # Loop thru args
  for ( $idx = 0; $idx -lt $args.count; $idx++ ) {
    $arg = $args[$idx]
    if ($passRest)
      {
        $script:medleyArgs += $args
        continue
      }
    switch($arg) {
      { @("-b", "--background") -contains $_ }
        {
          $script:bg= $true
        }
      { @("-d", "--display") -contains $_ }
        {
         $displayFlag = $true
         $display = $args[$idx+1]
         if ( ($idx + 1 -gt $args.count) -or ($display -match "^-") )
            {
              Write-Output "Error: the `"--display`" flag is missing its value" "Exiting"
              exit 33
            }
          if ( $display -notmatch ":[0-9]+" )
            {
              Write-Output "Error: the `"--display`" value is not of the form `":N`, where N is number between 0 and 63: $display" "Exiting"
              exit 33
            }
        }
      {  @("-h", "--help", "-z", "--man") -contains $_ }
        {
          $script:noviewer = $true
          $script:medleyArgs += $_
        }
      { @("-p", "--port") -contains $_ }
        {
          if ( ($idx + 1 -gt $args.count) -or ($args[$idx+1] -match "^-") )
            {
              Write-Output "Error: the `"-p / --port`" flag is missing its value" "Exiting"
              exit 33
            }
          $script:port = $args[$idx+1]
          if (( $script:port -notmatch "^[0-9]*`$" ) -or ( $script:port -le 1024) -or ( $script:port -gt 65535 ))
            {
              Write-Output "Error: the value of `"-p / --port`" flag is not an integer between 1025 and 65535: $script:port " "Exiting"
              exit 33
            }
          $idx++
        }
      { @("-u", "--update") -contains $_ }
        {
          $script:update = $true
        }
      {  @("-v", "--vnc") -contains $_ }
        {
          $vncRequested = $true
        }
      { @("-w", "--wsl") -contains $_ }
        { 
          if (-not (Test-WSLInstalled))
            {
              Write-Output "Error: The `"-w / --wsl`" flag was used, But WSL is not installed." "Exiting"
              exit 33
            }
          if ( ($idx + 1 -gt $args.count) -or ($args[$idx+1] -match "^-") )
            {
              Write-Output "Error: the `"--wsl`" flag is missing its value" "Exiting"
              exit 33
            }
          $script:wsl = $true
          $script:wslDistro = $args[$idx + 1]
          if (($script:wslDistro -ne "-") -and (-not (Test-WSLDistro $script:wslDistro)))
            {  
              Write-Output "Error: value of `"--wsl`" flag is not an installed WsL distro: $script:wslDistro." "Exiting"
              exit 33
            }
          if (-not (Test-MedleyInstalled $script:wslDistro))
            {
              Write-Output "Error: value of `"--wsl`" flag is an installed WsL distro, but Medley is not installed in standard location: $script:wslDistro." "Exiting"
              exit 33
            }
          $idx++
        }
      { @("-x", "--logindir") -contains $_ }
        {
          $script:logindir=$args[$idx+1]
          $idx++
        }
      { @("-y", "--draft") -contains $_ }
        {
          $script:draft="draft"
        }
      { $_ -eq "--" }
        {
          $passRest=$true
          $script:medleyArgs += $_
        }
      default
        { 
          $script:medleyArgs += $_
        }
      }
    }
  if ($script:logindir)
    {
      if ($script:wsl)
        {
          $script:medleyArgs = @( "--logindir", $script:logindir) + $script:medleyArgs
        }
    }
  if ($script:update -and $script:wsl) 
    {
       Write-Output "Warning: Both the -u or --update flag and the -w or --wsl flags were given. "
       Write-Output "The -u or --update flag is not relevant for wsl." 
       Write-Output "Ignoring the -u or --update flag."
    }
  if ($vncRequested)
    {
      if (-not $script:wsl) 
        {
          Write-Output "Warning: The -v or --vnc flag is not relevant when running under docker"
          Write-Output "Ignoring the -v or --vnc flag."
        }
      else
        {
          $script:medleyArgs = @( "--vnc") + $script:medleyArg
        }
    }
  if ($script:wsl -and $displayFlag)
    {
      $script:medleyArgs = @( "--display", "$display") + $script:medleyArg
    }
}

 

###############################################################################

#
#  Main script
#

#
#  Process the arguments
#
Process-Args @args

#
# If we're not calling wsl, check if docker is installed and running,
# check if logindir is a legitamte directory, do the pull if required.
#
if (-not $wsl)
  {
    # Make sure docker is installed
    if (-not (Test-DockerInstalled) )
      {
        Write-Output "Error: Docker is not installed on this system."
        Write-Output "This medley app requires Docker unless the --wsl flag is used"
        Write-Output "Exiting."
        exit 34
      }
    # Make sure docker is running
    if (-not (Test-DockerRunning) )
      {
        Write-Output "Error: The Docker engine is installed but not currently running on this system."
        Write-Output "This medley app requires the Docker Engine running unless the --wsl flag is used"
        Write-Output "Exiting."
        exit 33
      }
     # Check/create logindir
     if (-not (Test-Path -Path $logindir -PathType Container))
       {
         try 
           {
             $null = New-Item -ItemType Directory -Path ${logindir} -Force -ErrorAction Stop
           }
         catch 
           {
             Write-Output "Error: The specified logindir does not exist and cannot be created: ${logindir}"
             Write-Output "Exiting."
             exit 35
           }
       }
    # Do a pull if required
    if ($update -or (-not (docker image ls interlisp/medley:${draft} | Select-String medley)))
      {
        docker pull interlisp/medley:${draft}
      }
  } 

#
#  Call wsl or run docker
#
if ($wsl)
  {
    #
    # Call wsl
    #
    if ( $wslDistro -eq "-" )
      {
        $distro = @()
      }
    else

      { 
        $distro = @( "-d", $wslDistro )
      }
    wsl @distro medley @medleyArgs
  }
else
  
  {
   #
   # Run docker and vncviewer
   #

   # Find an open port to use for vnc
   if (-not $port) { $port=Find-OpenPort }
   Write-Output "Using VNC_PORT=$port"
   
   
   # Unless $noviewer is set (i.e., if --help and --man flag are set),
   # start the vncviwer in the background.
   # But wait for the docker container to actually come up
   # before starting it
   if (-not $noviewer)
     {
       Start-Job -InputObject "$port" -ScriptBlock { 
         $port = $input.Clone()
         $stopTime = (Get-Date).AddSeconds(10)
         $hit=$false
         while ((-not $hit) -and ((Get-Date) -lt $stopTime))
           {
             docker container ls | Select-String 'medley' | Select-String "${port}->5900" | Set-Variable "hit"
             if (-not $hit) { Start-Sleep -Milliseconds 250 }
           }
         if ($hit) 
           {
             Write-Host $hit
             vncviewer64-1.12.0.exe -geometry '+50+50' -ReconnectOnError=off −AlertOnFatalError=off localhost:${port}
           }
       } >$null
     }

   #
   # Run the docker container using medley as the entrypoint and passing on the args
   # Run in the foreground unless requested to run in the background by the -b flag.
   #

   if (-not $bg) 
     {
       docker run -it --rm -p ${port}:5900 -v ${logindir}:/home/medley/il --entrypoint medley --env TERM=xterm interlisp/medley:${draft} --windows @medleyArgs
     }
   else
     {
       $dockerArgs=@("run", "--rm", "-p", "${port}:5900", "-v", "${logindir}:/home/medley/il", "--entrypoint", "medley", "interlisp/medley:${draft}", "--windows") + $medleyArgs
       Start-Process -NoNewWindow -FilePath "docker" -ArgumentList $dockerArgs
     }
  }

###############################################################################
#
#  Done
#
###############################################################################

