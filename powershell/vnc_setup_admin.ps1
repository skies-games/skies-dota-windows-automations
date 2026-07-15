
#$pass = read-host "Please, enter the desired vnc password"
# or just set manually:
# $pass = "mypass" 
# in the shell
cd "C:\Program Files\uvnc bvba\UltraVNC"
./winvnc.exe -install
# doesn't work: ./createpasswd.exe -secure $pass
#so set the password manually in the vnc server settings