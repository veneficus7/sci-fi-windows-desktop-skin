; Shared body of the six hotspot skins (Record1-6). Each Record.ini sets:
;   N, Name, Scan, HoverImg, ShowIdle (0 = hidden record), ShowScan, HasEyes, Hot=0, Active=0
; Hot is flipped by this skin's own hover and by the terminal rows; Active by the terminal.
; Launching goes through the terminal so the status line, sound and [ACTIVE] stay in sync.

[Rainmeter]
Update=-1
AccurateText=1
Group=Arrakis
ContextTitle=Edit apps and labels
ContextAction=["notepad.exe" "#@#Variables.inc"]

[sText]
FontFace=#FontUI#
AntiAlias=1
StringAlign=CenterCenter
InlineSetting=CharacterSpacing | 0 | 3 | 0
StringEffect=Shadow
FontEffectColor=#ColShadow#
DynamicVariables=1

[MeterFrame]
Meter=Image
SolidColor=0,0,0,0
W=260
H=145

[MeterEyes]
; Kwisatz Haderach mode: the eyes glow permanently (only Record4 sits on the eyes).
Meter=Image
ImageName=#@#Images\eyes_glow.png
X=72
Y=32
Hidden=((#EyeGlow# * #HasEyes#) > 0 ? 0 : 1)

[MeterBoxIdle]
Meter=Image
ImageName=#@#Images\box_idle.png
X=70
Y=0
Hidden=((#Hot# + 1 - #ShowIdle#) > 0 ? 1 : 0)
DynamicVariables=1

[MeterBoxHover]
Meter=Image
ImageName=#@#Images\#HoverImg#
X=70
Y=0
Hidden=(1 - #Hot#)
DynamicVariables=1

[MeterScan]
Meter=Image
ImageName=#@#Images\#Scan#
X=92
Y=22
Hidden=((#Hot# * #ShowScan#) > 0 ? 0 : 1)
DynamicVariables=1

[MeterLabel]
Meter=String
MeterStyle=sText
Text=00#N#
FontSize=9.75
FontColor=#ColText#
X=131
Y=60
Hidden=((#Hot# + 1 - #ShowIdle#) > 0 ? 1 : 0)

[MeterActive]
; Shown under an idle visible box while its app is running.
Meter=String
MeterStyle=sText
Text=● ACTIVE
FontSize=7.5
FontColor=#ColSpice#
X=131
Y=126
Hidden=((#Active# * #ShowIdle# * (1 - #Hot#)) > 0 ? 0 : 1)

[MeterCaption]
Meter=String
MeterStyle=sText
Text=00#N# : #Name#
FontSize=10.5
FontColor=#ColSpice#
X=131
Y=130
Hidden=(1 - #Hot#)

[MeterHit]
Meter=Image
SolidColor=0,0,0,1
X=80
Y=10
W=101
H=101
MouseOverAction=[!SetVariable Hot 1][!UpdateMeter *][!Redraw][Play "#@#Sounds\#Sounds#\hover.wav"][!CommandMeasure mScript "Select(#N#)" "Arrakis\Terminal"]
MouseLeaveAction=[!SetVariable Hot 0][!UpdateMeter *][!Redraw][!CommandMeasure mScript "Deselect(#N#)" "Arrakis\Terminal"]
LeftMouseUpAction=[!CommandMeasure mScript "Launch(#N#)" "Arrakis\Terminal"]
