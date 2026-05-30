cd C:\Users\$env:username\Desktop\nebula
./nebula.exe -service install
set-service nebula -startuptype "automatic"
./nebula.exe -config "C:\Users\$env:username\Desktop\nebula\config.yaml"
start-service nebula