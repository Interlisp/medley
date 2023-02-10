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


function Process-Args {

  $script:wsl = $false
  $script:logindir = ""
  $script:port = $false
  $passRest = $false
  $script:medleyArgs = @()
  $script:draft = "latest"
  $script:bg = $false
  $script:update = $false
  $vncRequested = $false

  for ( $idx = 0; $idx -lt $args.count; $idx++ ) {
    $arg = $args[$idx]
    if ($passRest)
      {
        $script:medleyArgs += $args
        continue
      }
    switch($arg) {
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
      { @("-b", "--background") -contains $_ }
        {
          $script:bg= $true
        }
      { @("-y", "--draft") -contains $_ }
        {
          $script:draft="draft"
        }
      {  @("-v", "--vnc") -contains $_ }
        {
          $vncRequested = $true
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
}

#
#  Process the arguments
#
Process-Args @args

#
# We're not calling wsl, so check if docker is installed and running
# And if an update is called for, do so
#
if (-not $wsl)
  {
    if (-not (Test-DockerInstalled) )
      {
        Write-Output "Error: Docker is not installed on this system."
        Write-Output "This medley app requires Docker unless the --wsl flag is used"
        Write-Output "Exiting."
        exit 33
      }
    if (-not (Test-DockerRunning) )
      {
        Write-Output "Error: The Docker engine is not currently on this system."
        Write-Output "This medley app requires the Docker Engine running unless the --wsl flag is used"
        Write-Output "Exiting."
        exit 33
      }
    if ($update -or (-not (docker image ls interlisp/medley:${draft} | Select-String medley)))
      {
        docker pull interlisp/medley:${draft}
      }
  } 

#
#  Call wsl or docker
#
if ($wsl)
  {
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
   if (-not $port) { $port=Find-OpenPort }
   Write-Output "Using VNC_PORT=$port"
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
         C:\"Program Files"\TigerVNC2\vncviewer -geometry '+50+50' -ReconnectOnError=off −AlertOnFatalError=off localhost:${port}
       }
       
   } >$null
   if (-not $bg) 
     {
       docker run -it --rm -p ${port}:5900 --entrypoint medley --env TERM=xterm interlisp/medley:${draft} @medleyArgs
     }
   else
     {
       $dockerArgs=@("run", "--rm", "-p", "${port}:5900", "--entrypoint", "medley", "interlisp/medley:${draft}") + $medleyArgs
       Start-Process -NoNewWindow -FilePath "docker" -ArgumentList $dockerArgs
     }
   #$dockerArgs=@("run", "--rm", "-p", "${port}:5900", "--entrypoint", "medley", "interlisp/medley:${draft}") + $medleyArgs
   # Start-Process -NoNewWindow -FilePath "docker" -ArgumentList $dockerArgs
  }
