Invoke-WebRequest -URI https://aka.ms/vs/17/Release/vs_Community.exe -OutFile $Env:TMP\vs_Community.exe
$args = @(
  "--passive", "--includeRecommended",
  "--add Microsoft.VisualStudio.Workload.NativeDesktop",
  "--add Microsoft.VisualStudio.Component.VC.ATLMFC",
  "--add Microsoft.VisualStudio.Component.VC.Redist.MSM"
)
Start-Process -FilePath $Env:TMP\vs_Community.exe -Argumentlist $args -Wait

# Install chocolatey (this command is from https://chocolatey.org/install).
Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

choco install strawberryperl -y
choco install git -y -params '"/GitAndUnixToolsOnPath"'
choco install emacs -y
