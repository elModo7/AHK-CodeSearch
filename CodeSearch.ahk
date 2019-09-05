;-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
;--------------------------------------------						   Code Search - originally from fischgeek					 --------------------------------------------
;-------------------------------------------- 				  https://github.com/fischgeek/AHK-CodeSearch                  --------------------------------------------
;--------------------------------------------						modified by Ixiko - look below for version 					 --------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

version:= "05.09.2019"
vnumber:= 1.3

/*																	   		the modification list

				1. Ready to enter the search string right after the start
				2. pressing Enter after entering the search string starts the search immediately
				3. the buttons R, W, C now show their long name
																	V1.1
				4. the window displays the number of files read so far and the number of digits found during the search process
				5. Font size and window size is adapted to 4k monitors (Size of Gui is huge - over 3000 pixel width) - at the moment, no resize or
						any settings for the size of the contents is possible - i'm sorry for that
																	V1.2
				6. Stop/Resume Button is added - so the process can be interrupted even to start a new search
						6.a. from fischgeek Todo -  Find an icon - i take yours and it looks great!
																	V1.3
				7. Gui Resize for Listview control is working
				8. showing the last number of files in directory
				9. change the code to the coding conventions of AHK_L V 1.1.30.0

	Fischgeeks TODO:
		- Add ability to double-click open a file to that line number -> I can still do that
		- Add progress bar - nearly SOLVED -> I integrated counters
		- Add right-click context menu
			- Add option to open file location
		- Possibly add an extension manager?
		- Add pre-search checks (extension selection, directory)
		- Add auto saving of selected options and filters

File counter
Files with search string

*/

;{1. sript defaults - includes ----------------------------------------------------------------------------------------------------------------------------------------------------
SetBatchLines, -1
CoordMode, Pixel, Screen
CoordMode, Mouse, Screen
#Include %A_ScriptDir%\Classes\Config.ahk
Menu, Tray, Icon, %A_ScriptDir%\CodeSearch.ico
;FileInstall, CodeSearch.ico
;}

;{2. variables -------------------------------------------------------------------------------------------------------------------------------------------------------------------------
;maybe later for Resizefeature
baserate              	:= 1.8     ;(4k)
WinsizeBase      	:= 3000
GroupBoxBaseW	:= 500
GroupBoxBaseH 	:= 120
StaticTextBase    	:= 400

;Coloum width's
wFile     	:= 900
wLineText	:= 895
wLine    	:= 100
wPosition	:= 100

StopIT := 0
icount := maxCount:= 0
config := new Config()
;}

;{3. the Gui ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------
	Gui, Color, White
	Gui, +Resize HwndhCSGui
	Gui, Margin, 10, 10
	Gui, Font, s11, Segoe UI Light
	Gui, Add, Text,, % "Initial Directory:"
	Gui, Add, Edit, Section w300 h27 -Wrap vtxtInitialDirectory, % config.getValue("LastDir") ? config.getValue("LastDir") : ""
	Gui, Add, Button, hp+1 w40 ys-1 gbtnDirectoryBrowse_Click vbtnDirectoryBrowse, % "..."
	Gui, Add, Text, xm, % "String to search for:"
	Gui, Add, Edit, Section w300 HWNDhsearch vtxtSearchString
	Gui, Add, Button, ys-1 hp+1 vbtnSearch gbtnSearch_Click, % "Search"
	Gui, Add, Checkbox, Section checked xm w120 h30 0x1000 vcbxRecurse, % "RECURSE"
	Gui, Add, Checkbox, ys wp hp 0x1000 vcbxWholeWord, % "WHOLE WORD"
	Gui, Add, Checkbox, ys wp hp 0x1000 vcbxCase, % "CASESENSITIVE"
	Gui, Add, Button, ys w200 hp 0x1000 Center vSearchStop gbtnSearchStop , % "STOP SEARCHING"
	Gui, Add, GroupBox, ym w500 h120, % "File Types"
	Gui, Add, Checkbox, yp+30 xp+15 Section checked vcbxAhk, % ".ahk"
	Gui, Add, Checkbox, ys vcbxHtml, % ".html"
	Gui, Add, Checkbox, ys vcbxCss, % ".css"
	Gui, Add, Checkbox, ys vcbxJs, % ".js"
	Gui, Add, Checkbox, ys vcbxIni, % ".ini"
	Gui, Add, Checkbox, ys vcbxTxt, % ".txt"
	Gui, Add, Text, xs, % "Additional extension (ex. xml,cs,aspx)"
	Gui, Add, Edit, w300 vtxtAdditionalExtensions
	Gui, Add, GroupBox, ym w500 h120 , % "Statistics"
	Gui, Add, Text, yp+30 xp+15 w150 Right Section         	, % "File counter: "
	Gui, Add, Text, ys w400 vStatCount                             	, % SubStr("000000" icount, -3) "/" SubStr("000000" maxCount, -3)
	Gui, Add, Text, xs  w150 Right   				                   	, % "Files with search string: "
	Gui, Add, Text, ys        							 vStatFiles      	, %  ifiles
	Gui, Add, Text, xs  w150 Right                                      	, % "Searchstring found: "
	Gui, Add, Text, ys                                   vStatFound    	, % isub
	Gui, Add, Picture, ym w135 h130, %A_ScriptDir%\assets\4293840.png
	Gui, Add, Text, xp yp+120 	,  % "      a script by Fishgeek"
	Gui, Add, Text, xp yp+20  	, %  "modified by Ixiko " version
	Gui, Font, s11, Consolas
	Gui, Add, ListView, xm w2000 r40 glvResults_Click vlvResults, % "File|Line Text|Line #|Position"
	GuiControl, Disable, Button6
	Gui, Show, AutoSize Center, Code Search

	LV_ModifyCol(1, wFile)
	LV_ModifyCol(2, wLineText)
	LV_ModifyCol(3, wLine)
	LV_ModifyCol(4, wPosition)

	WinID:=WinExist("A")
	ControlGetPos, cx, cy,,, Edit2, ahk_id %WinID%
	ControlClick, Edit2, ahk_id %WinID%,,,, NA x%cx%+5 y%cy%+5
	x:= cx+40, y:=cy+15
	DllCall("SetCursorPos", int, x, int, y)
	GuiControlGet, lv, Pos, lvResults
	sleep, 2000

return

GuiSize:
	Critical, Off
	if A_EventInfo = 1  ; Das Fenster wurde minimiert.  Keine Aktion notwendig.
		return
	Critical
	wNew:= A_GuiWidth, hNew:= A_GuiHeight
	GuiControl, MoveDraw, lvResults, % "w" wNew - 20 " h" hNew - lvY - 10
	Critical, Off

return

;}

;{4. Hotkey ----------------------------------------------------------------------------------------------------------------------------
#IfWinActive Code Search
Enter::
	ControlGetFocus, focused, ahk_id %WinID%
	If (focused = "Edit2")
		ControlClick, Button2, ahk_id %WinID%
	else
		SendInput, {ENTER}
return

#IfWinActive
;}

return
; End of AutoExec ---------------------------------------------------------------------------------------------------------------------------------------------------------------------

;{5. Gui dialogs -----------------------------------------------------------------------------------------------------------------------------------------------------------------------
btnDirectoryBrowse_Click:	;{
	Gui, Submit, NoHide
	FileSelectFolder, targetDir, *C:\, 3, % "Select a starting directory."
	if ErrorLevel
		return

	if (targetDir != "")
	{
		GuiControl,, txtInitialDirectory, % targetDir
		config.setValue(targetDir, "LastDir")
	}
return ;}

btnSearchStop:                 	;{

	If (StopIT = 0)
	{
			StopIT := 1
			ControlGetPos, csx, csy,,, Button6
			csy-= 20, 	csx+= 30
			;ToolTip, Process will stop soon..., %csx%, %csy%, 3
	}
	else if (StopIT = 2)
	{
			StopIT := 0
			ControlSetText, Button6, % "STOP SEARCHING"
			Goto, resume
	}

return ;}

btnSearch_Click:            	;{

	GuiControl, Enable, Button6
	WinSetTitle, ahk_id %hCSGui%,, Code Search - I am searching
	Gui, Submit, NoHide

	LV_Delete()
	ControlSetText, Static5, % "Files with search string: "
	ControlSetText, Static6, % "      Searchstring found: "

	keyword	:= txtSearchString
	extensions	:= getExtensions()
	If !InStr(extensions, extensions_old)
		maxCount:= 0

	;extensions_old:= extensions

	recurse 	:= icount := ifiles 	:= isub	:= 0
	if cbxRecurse
		recurse := 1

    SetWorkingDir, %txtInitialDirectory%

resume:

	Critical
	Loop, *.*,, % recurse
	{
			if (StopIt = 1) 		;i want to have a stop and resume function -
			{
					StopIt:= 2
					ControlSetText, Button6, % "RESUME SEARCHING"
					WinSetTitle, ahk_id %hCSGui%,, Code Search - searching ist stopped
					ToolTip,,,,3
					 return
			}

			if A_LoopFileAttrib contains H,S,R
				continue
			if A_LoopFileExt not in %extensions%
				continue

			;filePath := A_LoopFileFullPath
			icount++
			GuiControl,, StatCount, % SubStr("000000" icount, -3) "/" SubStr("00000" maxCount, -3)

			FileRead, file, % filePath:= A_LoopFileFullPath
			Loop, Parse, % file, `n, `r
			{
					RegExMatch(A_LoopField, getRegExOptions(cbxCase) getExpression(keyword, cbxWholeWord), obj)
					if (obj.Len() > 0) ;## geändert
					{
							LV_Add("", filePath, truncate(A_LoopField), A_Index, obj.Pos())

							If (filePath <> file_old)
							{
									ifiles ++
									GuiControl,, StatFiles, % ifiles
									file_old:= filePath
							}

							isub++
							GuiControl,, Statsub, % isub
							adjHdrs("lvResults")
					}
			}

	}

	Critical, Off
	maxCount:= icount
	WinSetTitle, ahk_id %hCSGui%,, Code Search - ready with searching
	ControlSetText, Button6, % "STOP SEARCHING"
	StopIT := 0
	GuiControl, Disable, Button6

return
;}

lvResults_Click:          		;{

	Gui, Submit, NoHide
	dir := txtInitialDirectory
	LV_GetText(fileName, A_EventInfo)

	parameter:= dir "\" filename
	Run C:\Program Files\AutoHotkey\SciTE\scite.exe  "%parameter%"

return ;}

GuiClose: ;{

ExitApp
;}

;}

;{6. Functions --------------------------------------------------------------------------------------------------------------------------------------------------------------------------
listfunc(file){

	fileread, z, % file
	z:= StrReplace(z, "`r")     		                        	; important
	z := RegExReplace(z, "mU)""[^`n]*""", "")          	; strings
	z := RegExReplace(z, "iU)/\*.*\*/", "")              	; block comments
	z := RegExReplace(z, "m);[^`n]*", "")               	; single line comments
	p:=1 , z := "`n" z

	while q:=RegExMatch(z, "iU)`n[^ `t`n,;``\(\):=\?]+\([^`n]*\)[ `t`n]*{", o, p)
		lst .= Substr( RegExReplace(o, "\(.*", ""), 2) "`n"
		, p := q + Strlen(o)-1

	Sort, lst

return lst
}
adjHdrs(listView="") {
	Gui, ListView, %listView%
	Loop, % LV_GetCount("Col")
		LV_ModifyCol(A_Index, "autoHdr")
	LV_ModifyCol(1,"Integer Left")
	return
}
truncate(s, c="50") {
	if (StrLen(s) > c) {
		return SubStr(s, 1, c) " (...)"
	}
	return s
}
getExtensions() {
	global
	e := ""
	if (cbxAhk)
		e := "ahk,"
	if (cbxTxt)
		e .= "txt,"
	if (cbxIni)
		e .= "ini,"
	if (cbxHtml)
		e .= "html,"
	if (cbxCss)
		e .= "css,"
	if (cbxJs)
		e .= "js,"
	StringTrimRight, e, e, 1
	return e
}
getExpression(keyword, wholeWord) {
	if (wholeWord) {
		expression := "[\s|\W]?" keyword "[\s|\W]"
	} else {
		expression := keyword
	}
	return expression
}
getRegExOptions(caseSense) {
	options := "O" ; return regex match result as an object
	if (!caseSense) {
		options := options "i" ; case sensitive searching
	}
	return options ")"
}
;}







