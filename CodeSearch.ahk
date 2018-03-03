;-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
;--------------------------------------------						   Code Search - originally from fischgeek					 --------------------------------------------
;-------------------------------------------- 				  https://github.com/fischgeek/AHK-CodeSearch                  --------------------------------------------
;--------------------------------------------						modified by Ixiko - look below for version 					 --------------------------------------------
;-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

version:= "03.03.2018"

/*																	   		the modification list

				1. Ready to enter the search string right after the start
				2. pressing Enter after entering the search string starts the search immediately
				3. the buttons R, W, C now show their long name
				4. the window displays the number of files read so far and the number of digits found during the search process
				5. Font size and window size is adapted to 4k monitors


	TODO:
		- Add ability to double-click open a file to that line number
		- Add progress bar
		- Add right-click context menu
			- Add option to open file location
		- Add Anchor()
		- Account for additional extensions
		- Possibly add an extension manager?
		- Find an icon
		- Add pre-search checks (extension selection, directory)
		- Add finished notification (statusbar?)
		- Add auto saving of selected options and filters

File counter
Files with search string

*/
CoordMode, Pixel, Screen
CoordMode, Mouse, Screen
#Include Classes/Config.ahk

;maybe later for Resizefeature
baserate = 1.8     ;(4k)
WinsizeBase = 3000
GroupBoxBaseW = 500
GroupBoxBaseH = 120
StaticTextBase = 400

;Coloum width's
wFile = 900
wLineText = 895
wLine = 100
wPosition = 100


config := new Config()

Gui, Color, White
Gui, +Resize
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
Gui, Add, Text, yp+30 xp+15 w400 Section vStatCount, % "               File counter : " icount
Gui, Add, Text, xs  w400							 vStatFiles,     % "Files with search string: " ifiles
Gui, Add, Text, xs  w400                           vStatFound,   % "      Searchstring found: " isub
Gui, Add, Picture, ym w135 h130, assets\4293840.png
Gui, Add, Text, xp yp+120 ,  % "      a script by Fishgeek"
Gui, Add, Text,   xp yp+20 , %  "modified by Ixiko " version
Gui, Font, s11, Consolas
Gui, Add, ListView, xm w2000 r40 glvResults_Click vlvResults, % "File|Line Text|Line #|Position"
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
sleep, 2000

#IfWinActive Code Search

	Enter::
				ControlGetFocus, focused, ahk_id %WinID%
				If (focused = "Edit2") {
						ControlClick, Button2, ahk_id %WinID%
					} else {
						SendInput, {ENTER}
					}
	return

#IfWinActive



return

btnDirectoryBrowse_Click:
{
	Gui, Submit, NoHide
	FileSelectFolder, targetDir, *C:\, 3, % "Select a starting directory."
	if (ErrorLevel) {
		return
	}
	if (targetDir != "") {
		GuiControl,, txtInitialDirectory, %targetDir%
		config.setValue(targetDir, "LastDir")
	}
	return
}

btnSearch_Click:
{
	Gui, Submit, NoHide
	LV_Delete()
	keyword := txtSearchString
	extensions := getExtensions()
	recurse := 0
	if (cbxRecurse)
		recurse := 1
    SetWorkingDir, %txtInitialDirectory%
	icount:= 0
	ifiles:=0
	isub:= 0
	Loop, *.*,, %recurse%
	{				;1L Start
		if A_LoopFileAttrib contains H,S,R
			continue
		if A_LoopFileExt not in %extensions%
			continue
		file := A_LoopFileFullPath
			icount++
				ControlSetText, Static4, % "               File counter : " icount, Code Search

						Loop, Read, %file%
						{				;2L Start
							line := A_LoopReadLine
							RegExMatch(line, getRegExOptions(cbxCase) getExpression(keyword, cbxWholeWord), obj)
							if (obj.Len() > 0) {
								LV_Add("", file, truncate(line), A_Index, obj.Pos())

									If (file <> file_old) {
												ifiles ++
											ControlSetText, Static5, % "Files with search string: " ifiles, Code Search
											file_old:= file
															}

										isub++
									ControlSetText, Static6, % "      Searchstring found: " isub, Code Search
								adjHdrs("lvResults")
							}
						}				;2L End

		;isub:=0
	}    ;1L End
	WinSetTitle, Code Search,, Code Search
	return
}

lvResults_Click:
{
	Gui, Submit, NoHide
	dir := txtInitialDirectory
	LV_GetText(fileName, A_EventInfo)

		parameter = %dir%\%filename%
		Run C:\Program Files\AutoHotkey\SciTE\scite.exe  "%parameter%"

return
}

GuiClose:
{
	ExitApp
}

listfunc(file){
	fileread, z, % file
	StringReplace, z, z, `r, , All			; important
	z := RegExReplace(z, "mU)""[^`n]*""", "") ; strings
	z := RegExReplace(z, "iU)/\*.*\*/", "") ; block comments
	z := RegExReplace(z, "m);[^`n]*", "")  ; single line comments
	p:=1 , z := "`n" z
	while q:=RegExMatch(z, "iU)`n[^ `t`n,;``\(\):=\?]+\([^`n]*\)[ `t`n]*{", o, p)
		lst .= Substr( RegExReplace(o, "\(.*", ""), 2) "`n"
		, p := q+Strlen(o)-1

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