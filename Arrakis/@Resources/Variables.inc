[Variables]
; ==================================================================
;  ARRAKIS desktop - your settings
;  Edit, save, then Rainmeter tray icon > Refresh all.
;
;  *Cmd values use Rainmeter's run syntax: a program, URL or folder
;  in quotes, optionally followed by arguments.
;  *Proc is the process name used for the [ACTIVE] tag.
;  {USERPROFILE} is filled in by install.ps1 with your user folder.
;  Theme text and colours live in Themes\*.inc.
; ==================================================================

; ---- Records 001-003 are the visible boxes; 004-006 are hidden. ----
Rec1Name=BROWSER
Rec1Cmd="https://www.google.com"
Rec1Proc=msedge.exe
Rec2Name=DISCORD
Rec2Cmd="{USERPROFILE}\AppData\Local\Discord\Update.exe" --processStart Discord.exe
Rec2Proc=Discord.exe
Rec3Name=STEAM
Rec3Cmd="C:\Program Files (x86)\Steam\steam.exe"
Rec3Proc=steam.exe
Rec4Name=ANDROID STUDIO
Rec4Cmd="C:\Program Files\Android\Android Studio\bin\studio64.exe"
Rec4Proc=studio64.exe
Rec5Name=TELEGRAM
Rec5Cmd="{USERPROFILE}\AppData\Roaming\Telegram Desktop\Telegram.exe"
Rec5Proc=Telegram.exe
Rec6Name=VS CODE
Rec6Cmd="{USERPROFILE}\AppData\Local\Programs\Microsoft VS Code\Code.exe"
Rec6Proc=Code.exe

; ---- Navigation row under the title ----
Nav1Name=HOME
Nav1Cmd="{USERPROFILE}"
Nav2Name=DOCUMENTS
Nav2Cmd="{USERPROFILE}\Documents"
Nav3Name=PROJECTS
Nav3Cmd="{USERPROFILE}\AndroidStudioProjects"
Nav4Name=GALLERY
Nav4Cmd="{USERPROFILE}\Pictures"
Nav5Name=VIDEOS
Nav5Cmd="{USERPROFILE}\Videos"
Nav6Name=DOWNLOADS
Nav6Cmd="{USERPROFILE}\Downloads"

; ---- Footer links (the recycle bin and theme links are built in) ----
Foot1Name=SETTINGS
Foot1Cmd="ms-settings:"
Foot2Name=TASK MANAGER
Foot2Cmd="taskmgr.exe"
Foot3Name=RECYCLE BIN

; ---- Mentat: "terminal" opens this ----
PromptCmd="wt.exe"

; ---- Weather (install.ps1 -City "Your City" fills these in) ----
WeatherCity=
Latitude=
Longitude=
; wind speed in km/h that turns on the sandstorm wallpaper
StormWind=25

; ---- Focus timer default length in minutes ----
FocusMinutes=25

; ---- Sandworm appears above this download speed (bytes per second) ----
WormThreshold=200000

; ---- UI sounds: 1 = on, 0 = off ----
Sounds=1
