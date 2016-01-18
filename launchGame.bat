SET mypath=%~dp0
cd %mypath:~0,-1%
"..\Love2D\love.exe" "Game"
