;------------------------------------------------------------------------------------------------------------------------------------------------------
;--------------------------------------------						  Code Search - originally from fischgeek					 --------------------------------------------
;-------------------------------------------- 		 	    https://github.com/fischgeek/AHK-CodeSearch        --------------------------------------------
;--------------------------------------------						modified by Ixiko - look below for version 				 --------------------------------------------
;------------------------------------------------------------------------------------------------------------------------------------------------------
;
;		                  		A little promotion for Autohotkey:
;		                  		Autohotkey no longer enjoys my main attention, but I have yet to find anything better for finding program code
;		                  		on my computers than Fishgeek's codesearch program.  Other programs certainly achieve greater speed, but the
;		                  		foundation Fishgeek has laid and the ease with which further code highlighting can be integrated are unique.
;		                  		The nicest thing is how few resources an AHK script consumes in contrast to e.g. Python, and just copying the
;		                  		entire Codesearch directory is enough to run the code.
;
;------------------------------------------------------------------------------------------------------------------------------------------------------

version:= "2023-08-28"
vnumber:= 1.46


/*										                		VERSION HISTORY



                V1.46
				- Now you can enter a list of directories in which to search. The script determines the file endings contained in each directory.
					This allows you to include or exclude certain directories for the search to speed up the search.
				- Empty chars like a 'c' or 'D' without anything else will be interpreted as device letter
				- Highlighting for Python language and .ini files added (with hope it will work)
				- additional file types can be entered and will included in search

                V1.45
				- added area for displaying line numbers
				- the colours of the rest of the gui have been adapted to the codestyle
				- fixed incorrect behaviour when resizing the Treeview and RichCode controls

                V1.44
				- Search in files and/or file names
				- Added an RichCode (/Edit)-Control to show your found code highlighted
				- class_RichCode.ahk got additional functions
				- Removed the ListView for a TreeView control
				- Click on a sub-item in TreeView and it scrolls into view!
				- Add a context menu to the TreeView control with the options to Edit, Execute and Open Script Folder.
				- The width of TreeView and RichEdit-Control can be adjusted with a mouse drag in the gap between both controls.
				- Window position, size and the sizes of TreeView and RichCode control will be stored after closing the Gui.

                V1.3
				- Gui Resize for ListView control is working
				- Showing the last number of files in directory
				- Change the code to the coding conventions of AHK_L V 1.1.30.0
				- Ready to enter the search string right after the start
				- Pressing Enter after entering the search string starts the search immediately
				- The buttons R, W, C now show their long names

                V1.2
				- Stop/Resume Button is added - so the process can be interrupted even to start a new search
				- a. from fischgeek Todo -  Find an icon - i take yours and it looks great!

                V1.1
				- the window displays the number of files read so far and the number of digits found during the search process
				- Font size and window size is adapted to 4k monitors (Size of Gui is huge - over 3000 pixel width) - at the moment, no resize or
				  any settings for the size of the contents is possible - i'm sorry for that

	Fischgeeks TODO:
		- Add ability to double-click open a file to that line number -> I can still do that
		- Possibly add an extension manager?
		- Add pre-search checks (extension selection, directory)
		- Add auto saving of selected options and filters

*/

;{ script defaults --------------------------------------------------------------------------------------------------------------------------------------------------------------------

	#NoEnv
	SetBatchLines               	, -1
	CoordMode                   	, Pixel, Screen
	CoordMode                  	, Mouse, Screen
	CoordMode                  	, Menu, Screen
	SetTitleMatchMode       	, 2

	#MaxThreads                	, 250
	#MaxThreadsBuffer        	, On
	#MaxThreadsPerHotkey	, 4
	#MaxHotkeysPerInterval	, 99000000
	#HotkeyInterval            	, 99000000
	;#KeyHistory                 	, Off

	ListLines, Off

	Menu, Tray, Icon, % A_ScriptDir "\CodeSearch.ico"

;}

;{ variables -------------------------------------------------------------------------------------------------------------------------------------------------------------------------

		global hCSGui, hTV, hTP, RC
		global config, mFiles, TV, cbxCase, keyword, cbxWholeWord
		global txtInitialDirectory, AHKPath, AHKEditor
		global lastAdditionalExtensions, lastDirs

		global hCursor1    	:= DllCall("LoadCursor", "Ptr", 0, "Ptr", 32644, "Ptr")
		global hCursor2    	:= DllCall("LoadCursor", "Ptr", 0, "Ptr", 32512, "Ptr")
		global SearchBuffer	:= Object()
		global q           	:= Chr(0x22)
		global dbg        	:= false
		global ftypes       := [{"ext":"Ahk" , "fExt":".ahk,.ah2"	, "checked":0}
												,   {"ext":"Html", "fExt":".html"    	, "checked":0}
												, 	{"ext":"Css" , "fExt":".css"     	, "checked":0}
												, 	{"ext":"Js"  , "fExt":".js"     	, "checked":0}
												, 	{"ext":"Py"  , "fExt":".py"     	, "checked":0}
												, 	{"ext":"Ini" , "fExt":".ini"     	, "checked":0}
												, 	{"ext":"Txt" , "fExt":".txt"     	, "checked":0}]

	; get default Autohotkey files editor
		RegRead, EditWith, HKEY_CLASSES_ROOT\AutoHotkeyScript\Shell\Edit\Command
		RegExMatch(EditWith, "[A-Z]\:[A-Za-z\pL\s\-_.\\\(\)]+", path)
		SplitPath, A_AhkPath,, AHKPath
		AHKEditor         := path
		config          	:= new Config()

	;maybe later for Resizefeature
		baserate         	:= 1.8     ;(4k)
		WinSizeBase      	:= 3000
		GroupBoxBaseW    	:= 500
		GroupBoxBaseH    	:= 120
		StaticTextBase   	:= 400
		MarginX          	:= 10
		MarginY          	:= 10
		StopIT           	:= 0
		icount           	:= 0
		maxCount         	:= 0

	;Column width's
		wFile            	:= 500
		wLineText        	:= 495
		wLine            	:= 100
		wPosition	      	:= 100

	; load last window position and size
		gP	:= GetSavedGuiPos(MarginX, MarginY)
		TVw	:= config.getValue("TV_Width", "Settings", 800)
		TVw	:= TVw < 600 ? 600 : TVw
		TPw := isObject(gP) ? gP.W-TVw-5-(2*MarginX) :  600

	; for gui resize:
		wF1 := TVw/gP.W
		wF2	:= 1-wF1

	; load extensions settings
		txtAdditionalExtensions := lastAdditionalExtensions := config.getValue("additionalExtensions", "Settings")
		for each, ftype in ftypes {
			ftype.checked := config.getValue(ftype.ext "_checked", "Settings", (ftype.ext = "Ahk" ? 1 : 0))
			ftypeExtensions .= (ftypeExtensions ? ",":"") ftype.fExt
		}

	; load last used search directories
		lastdirs := GetLastDirs()

	; richedit settings
		Settings :=
		( LTrim Join Comments
		{
		"TabSize"           	: 4,
		"Indent"             	: "`t",
		"FGColor"           	: 0xEDEDCD,
		"BGColor"           	: 0x3F3F3F,
		"GuiBGColor1"       	: "555453",
		"GuiBGColor2"       	: "B8B7B6",
		"Font"                	: {"Typeface": "Futura Bk Bt", "Size": 9},
		"WordWrap"          	: false,

		"Gutter": {
			;"Width"          	: 40,
			"FGColor"        	: 0x9FAFAF,
			"BGColor"        	: 0x262626
		},

		"UseHighlighter"   	: True,
		"Highlighter"      	: "HighlightAHK",
		"HighlightDelay"    	: 200,

		"Colors": {
			"Comments"       	:	0x9FBF9F,
			"Functions"      	:	0x7CC8CF,
			"Keywords"       	:	0xE4EDED,
			"Multiline"      	:	0x7F9F7F,
			"Numbers"        	:	0xF79B57,
			"Punctuation"    	:	0x97C0EB,
			"Strings"        	:	0xCC9893,

			; AHK
			"A_Builtins"    	:	0xF79B57,
			"Commands"      	:	0xCDBFA3,
			"Directives"    	:	0x7CC8CF,
			"Flow"           	:	0xE4EDED,
			"KeyNames"      	:	0xCB8DD9,
			"Descriptions"   	:	0xF0DD82,
			"Link"           	:	0x47B856,

			; PLAIN-TEXT
			"PlainText" 	  	:	0x7F9F7F
			}
		}
		)

		Settings2 :=
		( LTrim Join Comments
		{
		"TabSize"          	: 4,
		"Indent"           	: "`t",
		"FGColor"         	: 0xEDEDCD,
		"BGColor"          	: 0x3F3F3F,
		"GuiBGColor1"      	: "555453",
		"GuiBGColor2"      	: "B8B7B6",
		"Font"            	: {"Typeface": "Futura Bk Bt", "Size": 9},
		"WordWrap"        	: false,

		"Gutter": {
			"Width"          	: 40,
			"FGColor"        	: 0x9FAFAF,
			"BGColor"        	: 0x262626
		},

		"UseHighlighter"   	: True,
		"Highlighter"      	: "HighlightAHK",
		"HighlightDelay"	  : 200,

		"Colors": {
			"Comments"      	:	0x9FBF9F,
			"Functions"     	:	0x7CC8CF,
			"Keywords"      	:	0xE4EDED,
			"Multiline"      	:	0x7F9F7F,
			"Numbers"        	:	0xF79B57,
			"Punctuation"    	:	0x97C0EB,
			"Strings"        	:	0xCC9893,

			; AHK
			"A_Builtins"    	:	0xF79B57,
			"Commands"      	:	0xCDBFA3,
			"Directives"    	:	0x7CC8CF,
			"Flow"           	:	0xE4EDED,
			"KeyNames"      	:	0xCB8DD9,
			"Descriptions"   	:	0xF0DD82,
			"Link"           	:	0x47B856,

			; PLAIN-TEXT
			"PlainText"   		:	0x7F9F7F
			}
		}
		)

		Settings3 :=
		( LTrim Join Comments
		{
		; When True, this setting may conflict with other instances of CQT
		"GlobalRun"         : False,

		; Script options
		"AhkPath"           : A_AhkPath,
		"Params"            : "",

		; Editor (colors are 0xBBGGRR)
		"FGColor"           : 0xEDEDCD,
		"BGColor"           : 0x3F3F3F,
		"GuiBGColor1"      	: "555453",
		"GuiBGColor2"      	: "D8D7D6",
		"TabSize"           : 4,
		"Font" : {
			"Typeface"        : "Consolas",
			"Size"            : 11,
		 	"Bold"            : False
	        	},

		"Gutter" : {
			"Width"        	  : 75,
			"FGColor"     	  : 0x9FAFAF,
			"BGColor"     	  : 0x262626
		},

		; Highlighter (colors are 0xRRGGBB)
		"UseHighlighter": True,
		"Highlighter": "HighlightAHK",
		"HighlightDelay": 200, ; Delay until the user is finished typing
		"Colors": {
			"Comments":     0x7F9F7F,
			"Functions":    0x7CC8CF,
			"Keywords":     0xE4EDED,
			"Multiline":    0x7F9F7F,
			"Numbers":      0xF79B57,
			"Punctuation":  0x97C0EB,
			"Strings":      0xCC9893,
			"A_Builtins":   0xF79B57,
			"Commands":     0xCDBFA3,
			"Directives":   0x7CC8CF,
			"Flow":         0xE4EDED,
			"KeyNames":     0xCB8DD9
		},

		; Auto-Indenter
		"Indent": "`t",

		; Pastebin
		"DefaultName": A_UserName,
		"DefaultDesc": "Pasted with CodeQuickTester",

		; AutoComplete
		"UseAutoComplete": True,
		"ACListRebuildDelay": 500 ; Delay until the user is finished typing
	}
	)

;}

;{ the Gui ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------

	bgt := " Backgroundtrans "

	; context menu
	funcEdit 	:= Func("ContextMenu").Bind("Edit")
	funcRun 	:= Func("ContextMenu").Bind("Run")
	funcExpl	:= Func("ContextMenu").Bind("Explorer")
	SearchIn 	:= ["Search in files and names", "Search only in files", "Search only filenames"]
	InNum   	:= 1

	Menu, CM, Add, Open in your code editor    	, % funcEdit
	Menu, CM, Add, Run code                    	, % funcRun
	Menu, CM, Add, open directory in explorer  	, % funcExpl


	;gui begin
	Gui, Color, % "c" StrReplace(Settings.GuiBGColor1, "0x"), % "c" StrReplace(Settings.GuiBGColor2, "0x")
	Gui, -DPIScale +Resize +LastFound +MinSize1920x800 HwndhCSGui 0x91CF0000 ; +LastFound and all controls will be shown at start without any problems
	Gui, Margin        	, % MarginX , % MarginY

	; directories
	Gui, Font, s9 q5 cWhite Bold	, Segoe UI Light
	Gui, Add, GroupBox 	, % "xm ym w580 h145 Center vGBSearchPaths hwndhGBSearchPaths"                 	, % "Directories"
	Gui, Font, cBlack Normal
	Gui, Add, Edit     	, % "xp+5 yp+30 w450 h30 r1 Section -Wrap vtxtInitialDirectory gIDirectory hwndhtxtInitDir"   , % "" ;txtInitialDirectory
	Gui, Add, Button    , % "x+5  h30 gbtnDirectoryBrowse_Click vbtnDirectoryBrowse  "                	, % "+"

	GuiControlGet, o, Pos, txtInitialDirectory
	p := GetWIndowSpot(hGBSearchPaths)
	Gui, Font, s7 cBlack Normal
	Gui, Add, ListView 	, % "x" oX " y" oy+oH+3 " w" oW+40 " h" p.CH-6 " -Hdr Grid Checked vLVSearchDirs gIDirectory hwndhLVSearchDirs", % "Path|Files"
	o := GetWindowSpot(hLVSearchDirs)
	Gui, ListView, LVSearchDirs
	LV_ModifyCol(1, Floor(o.CW*0.70))
	LV_ModifyCol(2, Floor(o.CW*0.30))
	LV_ModifyCol(3, 0)
	o := GetWindowSpot(hLVSearchDirs)
	GuiControl, Move, GBSearchPaths, % "h" (o.Y+o.H-p.Y+5) " w" (o.X+o.W-p.X+5)


	;search field
	x := o.X+o.W+10
	Gui, Font, s9 q5 cWhite Bold	, Segoe UI Light
	Gui, Add, GroupBox 	, % "x" x " ym w500 h145 Center vGBFileSearch hwndhGBFileSearch", % "String to search for"
	p := GetWIndowSpot(hGBFileSearch)
	Gui, Font, cBlack Normal
	opts := "HWNDhsearch vtxtSearchString gbtnSearch_Check"
	Gui, Add, Edit     	, % "x" x+5 " yp+30 Section w420 " opts	, % ""
	o := GetWIndowSpot(hSearch)
	Gui, Add, Button   	, % "x+5 ys h" o.H-2 " vbtnSearch gbtnSearch_Click"            	, % "Search"
	Gui, Add, Checkbox	, % "x" x+10 " y+10 Section checked h30 0x1000 vcbxRecurse"    	, % "RECURSE"
	Gui, Add, Checkbox	, % "x+3 hp 0x1000 vcbxWholeWord"                              	, % "WHOLE WORD"
	Gui, Add, Checkbox	, % "x+3 hp 0x1000 vcbxCase"                                   	, % "CASESENSITIVE"
	Gui, Add, Checkbox	, % "x" x+10 " y+5 hp 0x1000 vcbxSearchWhat gcbxClick "       	, % SearchIn[InNum]
	Gui, Add, Button   	, % "x+3 w200	hp 0x1000 Center vSearchStop gbtnSearchStop"      , % "STOP SEARCHING"


	;filetypes
	Gui, Font, s9 cWhite Bold
	x := p.X+p.W+10
	Gui, Add, GroupBox	, % "x" x " ym w580 h145 Center vGBFileTypes hwndhGBFileTypes" , % "File Types"
	for ftypeNr, ftype in ftypes {
		ftypepos := (ftypeNr=1 ? "yp+30 xp+15 Section hwndhftypes":"ys") " gbtnSearch_check "
		Gui, Add, Checkbox, % ftypepos " vcbx" fType.ext " " (ftype.checked ? "checked":"") , % RegExReplace(ftype.fext, "\.")
	}


	GuiControlGet, p, Pos, cbxAhk
	Gui, Add, Button   	, % "xs y+5 h" pH-10 " vbtnCheckAll gbtn_Click"                 	, % "check/uncheck all"
	Gui, Add, Text    	, xs y+5                                                        	, % "Additional extension (ex. xml,cs,aspx,rb)"
	Gui, Font, cBlack Normal
	Gui, Add, Edit     	, xs y+2 w550 vtxtAdditionalExtensions HWNDhaddExt              	, % txtAdditionalExtensions
	o := GetWindowSpot(haddExt)
	p := GetWindowSpot(hGBFileTypes)
	GuiCOntrol, Move, GBFileTypes , % "h" (o.Y+o.H-p.Y+10) " w" (o.X+o.W-p.X+10)
	GuiCOntrol, Move, GBFileSearch, % "h" (o.Y+o.H-p.Y+10)

	;statics
	Gui, Font, s9 cWhite, Segoe UI Light
	GuiControlGet, p, Pos, GBFileTypes
	x := pX+pW+10
	colLeftW := 250
	Gui, Add, GroupBox, % "x" x " ym w" colLeftW+280 " h" (o.Y+o.H-p.Y+10) " Center"                   	, % "Statistics"

	Gui, Font, s9 Normal, Consolas
	Gui, Add, Text, % "yp+40 xp+15 w" colLeftW " Right Section " bgt                , % "File counter:"
	Gui, Font, s9 Bold
	Gui, Add, Text, % "ys+0 w200 	vStatCount " bgt                                  , % SubStr("000000" icount, -3) . (StrLen(thisDirLastMaxCount) > 0 ? "/" SubStr("00000" thisDirLastMaxCount, -3) : "")

	Gui, Font, s9 Normal, Consolas
	Gui, Add, Text, % "xs w" colLeftW " Right Section " bgt                         , % "Path:"
	Gui, Font, s8 Bold
	Gui, Add, Text, % "ys+0 w300 	vStatPath " bgt                                   , % ""

	Gui, Font, s9 Normal, Consolas
	Gui, Add, Text, % "xs w" colLeftW " Right Section " bgt                         , % "Path counter:"
	Gui, Font, s8 Bold
	Gui, Add, Text, % "ys+0 w200 	vStatPathCount " bgt                              , % ""

	Gui, Font, s9 Normal
	Gui, Add, Text, % "xs w" colLeftW " Right Section vTFiles " bgt                	, % "Files with search string:"
	Gui, Font, Bold
	Gui, Add, Text, % "ys+0 w200  vStatFiles " bgt                                	, % ifiles

	Gui, Font, s9 Normal
	Gui, Add, Text, % "xs w" colLeftW " Right Section vTString " bgt               	, % "Searchstring found:"
	Gui, Font, Bold
	Gui, Add, Text, % "ys+0 w200   vStatFound " bgt                                	, % isub

	Gui, Font, s9 Normal
	Gui, Add, Picture, x+180 ym w150 h140 gCSReload vCSReload hwndCShReload        	, % A_ScriptDir "\assets\4293840.png"   ;w135 h130
	Gui, Add, Picture, xp yp w150 h140 vCSReload1 hwndCShReload1                    , % A_ScriptDir "\assets\4293840.png"   ;w135 h130
	Gui, Font, Bold
	Gui, Add, Text, xp-120 yp+130 w400 Center BackgroundTrans                      	, % "a script by Fishgeek"
	Gui, Add, Text, yp+25  w400 Center BackgroundTrans                             	, % "modified by Ixiko V" vnumber " (" version ")"


	;debug
	GuiControlGet, p, Pos, CSReload
	Gui, Font, s8 q5 cBlack, Segoe UI Light
	Gui, Add, Text, % "x" px+pW+30   	" y20 w800 h120 Wrap vDebug1"
	Gui, Add, Text, % "x" px+pW+840 	" y20 w800 h120 Wrap vDebug2"

	;treeview
	p := GetWIndowSpot(hGBSearchPaths)
	h := gP.H-p.Y-p.H-10-MarginY
	Gui, Font, s9 q5, Consolas
	Gui, Add, Treeview, % "xm y" p.Y+p.H+20 " w" TVw " h" h " AltSubmit gResultsTV vtvResults HWNDhTV Section"

	;richcode
	GuiControlGet, p, Pos, tvResults
	RCPos 	:= "x" pX+pW+5 " y" pY " w" TPw-10 " h" pH " "
	RC    	:= new RichCode(Settings3, RCPos, 1)
	hTP   	:= RC.hwnd
	hGtr  	:= RC.gutter.hwnd
	DocObj  := RC.GetTomObject("IID_ITextDocument")
	;~ RC.AddMargins(5, 5, 5, 5)
	RC.ShowScrollBar(0, False)

	GuiControl, Disable   	, SearchStop
	GuiControl, Disable   	, btnSearch
	GuiControl,           	, txtInitialDirectory, % ""
	GuiControl, Focus     	, txtSearchString


	If (gP.X < -20) {
		Gui, Show,      	, Code Search
		Gui, Maximize
	}
	else {
		Gui, Show, % "x" gP.X " y" gP.Y " w" gP.W " h" gP.H	, Code Search
	}

	If gP.M
		Gui, Maximize

	;hope this will fix the empty gui effect
	wp := GetWindowSpot(hCSGui)
	SetWindowPos(hCSGui, wp.X, wp.Y, wp.W+2	, wp.H+2, 0, 0x40)
	SetWindowPos(hCSGui, wp.X, wp.Y, wp.W 	, wp.H	, 0, 0x40)


	hTP := GetHex(hTP), hTV := GetHex(hTV)
	OnMessage(0x200 	, "OnWM_MOUSEMOVE")
	OnMessage(0x020  	, "OnWM_SETCURSOR")

	GuiControlGet	, TV, Pos, tvResults

	SearchIsFocused:= Func("ControlIsFocused").Bind("Edit2")
	Hotkey, If       	, % SearchIsFocused
	Hotkey, ~Enter   	, btnSearch_Click
	Hotkey, If




return

GuiSize: ;{
	if (A_EventInfo = 1)
		return
GuiSizePre:
	GuiControl, -Redraw, % "tvResults"
	GuiControl, -Redraw, % RC.gutter.hwnd
	GuiControl, -Redraw, % RC.hwnd
	wNew	:= A_GuiWidth     	, hNew	:= A_GuiHeight
	TVw  	:= Floor(wNew*wF1)	, PrW	:=  Floor(wNew*wF2)- RC.gutter.W - 1
	Critical Off
	Critical
	GuiControl, Move, tvResults         	, % " h" hNew - TVy - 5   	"w"	TVw - 5
	GuiControl, Move, % RC.gutter.hwnd  	, % " h" hNew - TVy - 5   	"x"	TVw + 1
	GuiControl, Move, % RC.hwnd         	, % " h" hNew - TVy - 5   	"x"	TVw + RC.gutter.W + 1 " w" PrW
	Critical Off
	GuiControl, +Redraw, % "tvResults"
	GuiControl, +Redraw, % RC.gutter.hwnd
	GuiControl, +Redraw, % RC.hwnd
	RedrawWindow(hCSGui)
return ;}

cbxClick: ;{

	InNum := InNum+1 >3 ? 1 : InNum+1
	GuiControl, Text	, cbxSearchWhat, % SearchIn[InNum]
	GuiControl,      	, cbxSearchWhat, 0

return ;}

TOff:
	ToolTip,,,, 14
return


;}

;{ gui dialogs -----------------------------------------------------------------------------------------------------------------------------------------------------------------------
btnDirectoryBrowse_Click:            	;{

	Gui, Submit, NoHide
	Gui, ListView, LVSearchDirs


	startingPathFound := false
	if LV_GetCount()
		Loop % LV_GetCount() {
			LV_GetText(startingPath, LV_GetCount()-A_Index+1, 1)
			if Instr(FileExist(startingPath), "D") {
				startingPathFound := true
				break
			}
		}

	if startingPathFound {
		SplitPath, startingPath,,,,, OutDrive
	}
	else
		OutDrive := "C:"

												;Gui=0, Title="",  Filter="", DefaultFilter="", Root="", DefaultExt="",
	;~ targetDir := Dlg_Openfile(hCSGui, "Select a folder", "", "", OutDrive "\", "PathMustExist")
	If !IsObject(targetDir := SelectFolderEx(OutDrive "\", "Select a folder", hCSGui, "", "", 1)) {
		MsgBox, 0x1000, % ScriptName, % " You have nothing selected."
	return
	}

	targetDir := targetDir.SelectedDir
	SciTEOutput("targetDir: " targetDir)

	pathmatched := false
	For searchPath, data in lastDirs {

		if (searchPath = targetDir) {
			MsgBox, 0x1000, % ScriptName , % "This path already exists!"
			return
		}
		else if (Strlen(targetDir) < Strlen(searchPath)) && (targetDir ~= "i)^" searchPath) {
			MsgBox, 4659, % ScriptName, % targetDir " is the parent path of " searchPath ".`n"
																			. "If you search the current directory recursively,`n"
																			.	"the last named directory would be included. `n"
																			. "You can now discard (NO) the directory that was included anyway,`n"
																			. " keep it (YES) or cancel the process here."

			IfMsgBox, Cancel
				return
			IfMsgBox, No
				lastDirs.Remove(searchpath)



		}
		else if (Strlen(targetDir) > Strlen(searchPath)) && (searchPath ~= "i)^" targetDir) {
				MsgBox, 4659, % ScriptName, % searchPath " is the parent path of " targetDir ".`n"
																			. "If you search the current directory recursively,`n"
																			.	"the last named directory would be included. `n"
																			. "You can now discard (NO) the directory that was included anyway,`n"
																			. " keep it (YES) or cancel the process here."

			IfMsgBox, Cancel
				return
			IfMsgBox, No
				return

		}


	}

	if !IsObject(lastDirs)
		lastDirs := Object()

	lastDirs[targetDir] := {"fTypes":{}, "active":1, "MaxCount":0}

	LV_Delete()
	if IsObject(lastDirs) {
		SaveLastDirs()
		GuiControl, Disable, SearchStop
		Gui, ListView , LVSearchDirs
		for searchpath, data in lastDirs {
			fext := ""
			for each, sfext in data.fTypes
				fext .= (fext ? ",":"") sfext
			LV_Add((data.active ? "Check" : ""), searchPath, fext)
		}
	}




return ;}

btn_Click:                            ;{

	if (A_GuiControl = "btnCheckAll") {

		check := (GetCheckedFileTypes() < ftypes.Count()//2) ? true : false
		for each, ftype in ftypes
			GuiControl,, % "cbx" ftype, % check

	}

return ;}

btnSearchStop:                      	;{

	If (StopIT = 0)	{
		StopIT := 1
		WinSetTitle, % "ahk_id " hCSGui,, % "Code Search - searching ist stopped"
		GuiControl,, SearchStop, % "RESUME SEARCHING"
		DisEnable("Enable")
	}
	else if (StopIT = 1)	{
		StopIT := 0
		WinSetTitle, % "ahk_id " hCSGui ,, Code Search - I am searching
		GuiControl,, SearchStop, % "STOP SEARCHING"
		DisEnable("Disable")
	}

return ;}

btnSearch_Check:                      ;{                                         ; enables/disables the searchbutton

	Gui, Submit, NoHide

	ftypesChecked := GetCheckedFileTypes()
	addExtensions	:= getAdditionalExtensions()
	searchPaths  	:= GetSearchPaths()

	if (txtSearchString && (ftypeChecked || addExtensions) && searchPaths.Count())
		GuiControl, Enable, btnSearch
	else
		GuiControl, Disable, btnSearch

return ;}

btnSearch_Click:                  		;{

	global TV          	:= Array()
	global mFiles     	:= Object()
	global TVIndex1   	:= TVIndex2:= StopIT:= icount := ifiles := isub := StopIT := 0
	PreviewFile_old     := ""
	Ballon_Tip          := 0

	Gui, Submit, NoHide

	ftypesChecked := GetCheckedFileTypes()
	addExtensions	:= getAdditionalExtensions()
	allExtensions := ftypeExtensions (addExtensions ? "," addExtensions: "")
	searchPaths  	:= GetSearchPaths()

	if !searchPaths.Count() {
		Ballon_Tip |= 1
		Edit_BalloonTip(htxtInitDir, "Leave directory strings here!", "Every search needs a starting point.", true)
		GuiControl, Focus, txtInitialDirectory
	}

	If (!ftypesChecked && !addExtensions) {
		Edit_BalloonTip(hftypes, "File type!", "Please check a file type..."   , true)
		Edit_BalloonTip(haddExt, "File type!", "or leave some extensions here!", true)
		Ballon_Tip |= 2
	}

	while !InStr(FileExist(txtInitialDirectory), "D") {

		switch A_Index {

			Case 1:
				if (xpath ~= "i)^[A-Z]{1,}$")
					xpath := Format("{:U}", xpath) . (StrLen(xpath) = 1 ? ":\" : "\\")

				if InStr(FileExist(xpath), "D") {
					GuiControl, Disable     , SearchStop
					GuiControl,            	, txtInitialDirectory, % xpath
					GuiControl, Choosestring, txtInitialDirectory, % xpath
					GuiControl, Focus       , txtSearchString
					config.setValue(xpath, "LastDir")
				}
				else {
					Edit_BalloonTip(htxtInitDir, "Leave a correct directory string here!", "Every search needs a starting point.", true)
					Ballon_Tip |= 4
					break
				}

			Case 2:
				Edit_BalloonTip(htxtInitDir, "Leave a correct directory string here!", "Every search needs a starting point.", true)
				Ballon_Tip |= 4
				break

			}

	}

	if (Ballon_tip > 0) {

		GuiControl, Disable, BtnSearch
		SetTimer, Ballon_Tip_off, -5000
		return

	}


 ; the search begins
	TV_Delete()

	WinSetTitle, % "ahk_id " hCSGui ,, Code Search - I am searching
	GuiControl,           	, StatFiles	, 0
	GuiControl,           	, StatFound	, 0
	GuiControl,           	, SearchStop, % "STOP SEARCHING"
	GuiControl, Enable    	, SearchStop
	DisEnable("Disable")

	extensions  := getExtensions() (addExtensions ? "," addExtensions : "")
	keyword     := txtSearchString

	If (last_txtSearchString != txtSearchString || last_extensions <> extensions) {
		last_txtSearchString  := txtSearchString
		last_extensions       := extensions
		SearchBuffer          := Object()
		fullindexed           := false
		;config.setValue(txtInitialDirectory, "LastDir")
	}

	; search path after path
	icount := scount := 0
	allDirs    := GetLastFilesCount()
	fpathtypes := Object()

	for each, searchpath in searchPaths {

		SetWorkingDir, % searchpath
		GuiControl,, StatPath, % StatPath
		scount := 0

		if allDirs.MaxCount
			SetStatCount(0, allDirs.MaxCount, 0, allDirs.spath[searchPath].MaxCount)

		fpathtypes[searchpath] := Object()
		if (!SearchBuffer.Count() || !fullindexed)
			gosub FilesSearch
		else
			gosub Buffersearch

		for fext, fextCount in fpathtypes[searchpath] {
			if !IsObject(lastDirs[searchpath])
				lastDirs[searchpath] := Object()
			if !IsObject(lastDirs[searchpath].fTypes)
				lastDirs[searchpath].fTypes := Object()

			lastDirs[searchpath].fTypes[fext] += fextCount
		}

	}

	SetStatCount(icount, allDirs.MaxCount, scount, allDirs.sPaths[searchPath].MaxCount)
	;config.setValue(icount , txtInitialDirectory, "LastFilesInDir")

 ; count all
	lastDirs.MaxCount := 0
	for each, searchpath in lastDirs {
		searchpath.MaxCount := 0
		for fExt, fextCount in searchpath.fTypes {
			searchpath.MaxCount += fextCount
			lastDirs.MaxCount += fextCount
		}
	}

 ; save paths
	SaveLastDirs()


	WinSetTitle, % "ahk_id " hCSGui,, Code Search - ready with searching
	GuiControl,        	, SearchStop    	, % "STOP SEARCHING"
	GuiControl, Disable	, SearchStop
	DisEnable("Enable")

return

Ballon_Tip_Off: ;{

	if BallonTip & 1 {
		Edit_BalloonTip(hftypes, "File type!", "Please check a file type!", false)
		Edit_BalloonTip(haddExt, "File type!", "or leave some extensions here!", false)
	}
	if BallonTip & 2
		Edit_BalloonTip(htxtInitDir, "Leave directory strings here!", "Every search needs a starting point.", true)
	if BallonTip & 4
		Edit_BalloonTip(htxtInitDir, "Leave a better directory string here!", "Every search needs a starting point.", false)
	if BallonTip & 4
		Edit_BalloonTip(htxtInitDir, "Leave a directory string here!", "Every search needs a starting point.", false)

return ;}

;}

FilesSearch:                        	;{

	fullindexed := false
	Loop, Files, % searchpath "\*.*", % (cbxRecurse ? "R":"")
	{
		While (StopIT = 1)
			loop 30
				sleep 10

		if A_LoopFileAttrib contains H,S,R
			continue
		if A_LoopFileExt in %allExtensions%
			fpathtypes[searchpath][A_LoopFileExt] := !fpathtypes[searchpath][A_LoopFileExt] ? 1 : fpathtypes[searchpath][A_LoopFileExt]+1
		if A_LoopFileExt not in %extensions%
			continue

		icount ++
		scount ++
		SetStatCount(icount, allDirs.MaxCount, scount, allDirs.sPaths[searchpath].MaxCount)

		filePath	:= A_LoopFileFullPath
		fileName 	:= A_LoopFileName

		try
			txt	:= FileOpen(filepath, "r").Read()
		catch
			continue

		SearchBuffer.Push({"path":filePath, "txt":txt})
		FindAndShow(txt, filepath)

	}

	GuiControl,, StatFound, % isub
	fullindexed := true

return ;}

BufferSearch:                       	;{

	;~ Sciteoutput(SearchBuffer.Count() "`n" SearchBuffer[1].txt)
	modDiv := StrLen(SearchBuffer.Count()) < 3 ? 1 : 100

	For buffIndex, file in SearchBuffer {

		While (StopIT = 1)
			loop 30
				sleep 10

		FindAndShow(file.txt, file.path)
		If (Round(Mod(buffIndex, modDiv)) = 0)
			SetStatCount(buffIndex, SearchBuffer.Count(), 0, 0)

	}

	SetStatCount(buffIndex, SearchBuffer.Count(), 0, 0)
	icount := buffIndex

return ;}

FindAndShow(txt, filepath)          	{                                       	; search txt, filenames and show matches in TreeView

	global ; cbxCase, keyword,cbxWholeWord

	  ; Filename matching
	  ; only search in filenames all things continues here, InNum holds the search mode: [1] is search in files and filenames, [2] only in files , [3] only in filenames
		If (InNum ~= "^(1|3)$") {
			RegExMatch(filename, getRegExOptions(cbxCase) getExpression(keyword, cbxWholeWord), obj)
			If (obj.Len() > 0)
				If !mFiles.HasKey(filepath) {
					SplitPath, filepath, outFileName, OutDir
					TVIndex1 ++
					TV[TVIndex1]    	:= Array()
					TV[TVIndex1]    	:= TV_Add(outFileName " [" OutDir "]" )
					mFiles[filepath] 	:= Object()
					mFiles[filepath].Push({"line":lineNr, "linepos":obj.Pos(), "TVIndex1":TVIndex1})
				}

	  ; search only in filenames continues here
			If (InNum = 3)
				return
		}

	  ; search in file text
		For lineNr, lineText in StrSplit(txt, "`n", "`r") 		{

			RegExMatch(lineText, getRegExOptions(cbxCase) getExpression(keyword, cbxWholeWord), obj)
			if (obj.Len() > 0) {

				; file is always listed
					If mFiles.HasKey(filepath) {

						idx1 := mFiles[filepath][1].TVIndex1
						idx2 := mFiles[filepath].MaxIndex() + 1
						TV[idx1][idx2] := TV_Add("[l:" Substr("0000" lineNr, -4) " p:" SubStr("000" obj.pos(), -2) "] " truncate(lineText, 120), TV[idx1])

						mFiles[filepath].Push({"line":lineNr, "linepos":obj.Pos()})

					}
					else {

						SplitPath, filepath, outFileName, OutDir
						TVIndex1 ++
						TV[TVIndex1]   	:= Array()
						TV[TVIndex1]   	:= TV_Add(outFileName " [" OutDir "]" )
						TV[TVIndex1][1]	:= TV_Add("[l:" Substr("0000" lineNr, -4) " p:" SubStr("000" obj.pos(), -2) "] " truncate(lineText, 120), TV[TVIndex1])

						mFiles[filepath] 	:= Object()
						mFiles[filepath].Push({"line":lineNr, "linepos":obj.Pos(), "TVIndex1":TVIndex1})

					}

					If (filePath <> filePath_old) {
						ifiles ++
						GuiControl,, StatFiles, % ifiles
						filePath_old := filePath
					}

					isub++
					If Mod(isub, 30) = 0
						GuiControl,, StatFound, % isub

			}
		}


}

ResultsTV:	                        	;{

	Gui, Submit, NoHide

	CrtLine1 := RC.GetCaretLine()
	global EventInfo:= A_EventInfo

	If RegExMatch(A_GuiEvent, "i)(Normal|S)$") && (A_EventInfo <> 0)	{

			TVText := TV_GetInfo(EventInfo)
			RegExMatch(TVText.parent, "(.*)\s+\[(.*)\]", match)
			PreviewFile := match2 "\" match1

			If (PreviewFile != PreviewFile_old) {

				RC.Settings.Highlighter := GetHighlighter(PreviewFile)
				RC.Value              	:= FileOpen(PreviewFile, "r").Read()
				RC.UpdateGutter()

				CurrentSel    	:= RC.GetSel()                      	; get the current selection

				CF2             := RC.GetCharFormat()
				CF2.Mask      	:= 0x40000001	    	              		; set Mask (CFM_COLOR = 0x40000000, CFM_BOLD = 0x00000001)
				CF2.Effects    	:= 0x01                              	; set Effects to bold (CFE_BOLD = 0x00000001)
				CF2.TextColor 	:= 0x006666
				CF2.BackColor 	:= 0xFFFF00
				RC.SetFont({BkColor:"YELLOW", Color:"BLACK"})
				;RC.SetSel(0,0)
				;RC.SetScrollPos(0,CaretLine-1)
				;RC.SetScrollPos(LineX+0,LineY+0)
				;RC.FindText(txtSearchString, ["Down"])
				;RC.SetScrollPos(0,0)
				PreviewFile_old := PreviewFile
			}

			upOrWhat := 0
			RegExMatch(TVText.child, "\[l\:(?<Y>\d+)\s+p\:(?<X>\d+)\]\s+(?<Text>.*)$", Line)
			If !RC.FindText(lineText, ["Down"])        	; search down
				RC.FindText(lineText), upOrWhat := 1    	; search up
			RC.ScrollCaret()
			RC.ScrollLines(upOrWhat ? "-40": "40")
			RC.ScrollCaret()
			RC.SyncGutter()

			;DocObj.
			CrtLine2 := RC.GetCaretLine()
			If dbg
				GuiControl,, Debug1,  % "CaretLine1: " CrtLine1 "`nCaretLine2: " CrtLine2 "`nLine: x" LineX+0 " y" LineY+0 "`nScrollPos x" ScrollPos.X " y" ScrollPos.Y

	}
	else if InStr(A_GuiEvent, "RightClick") && (A_EventInfo <> 0) {
			MouseGetPos, mx, my, mWin, mCtrl, 2
			Menu, CM, Show, % mx - 20, % my + 10
    }

return ;}
IDirectory:                          	;{

	Gui, Submit, NoHide

	If Instr(A_GuiControl, "txtInitialDirectory") && Instr(A_GuiControlEvent, "Normal") {
		;DirMaxCount := config.getValue(txtInitialDirectory, "LastFilesInDir", 0)
		SetStatCount(0, lastDirs.MaxCount, 0, 0)
		GuiControl,, StatFiles   	, % ""
		GuiControl,, StatFound   	, % ""
	}

return ;}
CSReload:                           	;{
	SaveGuiPos()
	SaveLastDirs()
	Reload
return ;}
GuiClose: 	                        	;{
	SaveGuiPos()
	SaveLastDirs()
ExitApp
;}
RCHandler(p1,p2,p3,p4)              	{
	If dbg
		GuiControl,, Debug2,  % "GCE: " p1 " | GE: " p2 " | AEI: " p3 "`nCL: " p4
}
ContextMenu(MenuName)               	{

	TVText := TV_GetInfo(Eventinfo)

	If Instr(MenuName, "Edit")
		Run, % q AHKEditor q " " q TVText.fullfilepath q,, Hide
	else If Instr(MenuName, "Run") {
		scriptText := FileOpen(TVText.fullFilePath, "r", "UTF-8").Read()
		RegExMatch(scriptText, "i)#Requires\s+AutoHotkey\s+v(?<v>\d+)", AHK)
		AHKv := !AHKv ? 1 : AHKv

		Run, % q A_AhkPath q " " q TVText.fullfilepath q,, Hide
	}
	else If Instr(MenuName, "Explorer")
		Run % COMSPEC " /c explorer.exe /select, " q TVText.fullfilepath q,, Hide

}

;}

;{ functions --------------------------------------------------------------------------------------------------------------------------------------------------------------------------
OnWM_MOUSEMOVE(wParam, lParam, msg, hWnd) 	                                	{

  Global hCursor1, hCursor2, hCSGui, hFooter, CShReload, hTV, hTP, hGtr
	Static hOldCursor, lasthwnd
	Static mCursor 	:= false
	Static moving 	:= false
  Static PrevX  	:= -1, x2 := -1

	hwnd := GetHex(hwnd)

	If (lasthwnd != hwnd) {

		If (hwnd = CShReload) {

			callfunc := Func("FishMove").Bind(CShReload)
			SetTimer, % callfunc, -1

		}

		lasthwnd := hwnd
	}

	If (hwnd = hTV || hwnd = hTP) {

		focused 	:= GetFocusedControlHwnd(hCSGui)
		If (hwnd != focused)
			ControlFocus,, % "ahk_id " hwnd

	}

	CoordMode Mouse, Client
	MouseGetPos, x1, y1, hWin, hCtrl, 2

	GuiControlGet lv	, Pos, % hTV
	GuiControlGet gtr	, Pos, % hGtr
	GuiControlGet tp	, Pos, % hTP
	WinGetPos,,, csW,, % "ahk_id " hCSGui

	If dbg {
		ToolTip, % "MMove: " hCtrl " [hTV: " hTV ", hTP: " hTP "]`n"
							. "hWin: " hWin ", w" w "`n"
							. "mx > hTV = " (x1>=(lvX+lvW-10)) " : mx < hTP = " (x1<=tpX+10) "`n"
							. "LButton Down: " GetKeyState("LButton", "P"), 2000, 300, 2
	}

	If  (x1 > (lvX + lvW - 10) && (x1 < tpX + 10) && (y1<(tpy+tph)) && (y1>tpy)) { ; (hWnd == hCSGui) ||

		 If (x1 > (lvX + lvW - 10) && (x1 < tpX + 10) && (y1<(tpy+tph)) && (y1>tpy)) {
			hOldCursor := DllCall("SetCursor", "Ptr", hCursor1, "Ptr")
			mCursor := true
			}
			else {
				if mCursor && !moving {
					mCursor := false
					hOldCursor := DllCall("SetCursor", "Ptr", hCursor2, "Ptr")
				}
			}

		PrevX := 0
		Offset := x1 - lvW
		RCw := RC.gutter.W

    While (GetKeyState("LButton", "P")) {

			moving := true

			MouseGetPos x2


			If (x2 == PrevX)
				Continue

			PrevX 	:= x2
			x      	:= gtrX + (x2 - x1)
			w      	:= gtrW + tpW	+ (x1 - PrevX)

			If (w<csW*0.25) || (w>csW*0.85)
				continue

			GuiControl Move, % hTV	, % "w" (x2 - Offset)
			GuiControl Move, % hGtr	, % "x" x
			GuiControl Move, % hTP	, % "x" x+gtrW+1 " w" w-gtrW-1

			;~ ToolTip, % "hTV " hTV ", % w" (x2 - Offset) "`nhTP " hTP ", % x" x " w" w

			Sleep 1

		}

		moving := false

	}

}
OnWM_SETCURSOR(wParam, lParam, msg, hWnd)                                    	{

    CoordMode Mouse, Client
    MouseGetPos x, y
    GuiControlGet tp	, Pos, % hTP
    GuiControlGet lv	, Pos, % hTV

     If (x>(lvX+lvW-10) && (x<tpX+10) && (y<(tpy+tph)) && (y>tpy))  {
		hOldCursor := DllCall("SetCursor", "Ptr", hCursor1, "Ptr")
       Return True
     }

}

FishMove(hwnd)                                                                {

	static _initMove:=false
	static movePix := [[6,1],[8,3],[10,6]]
	static aniPos:=1, aniLoop := 0, retZPos := 0, dir := 1
	static horizontal, maxDelta, velocity, maxXa, maxXb
	static cpX, cpY, cpXo, cpYo, move

	CoordMode, ToolTip, Screen

	If !_initMove {
		GuiControlGet, cp, Pos, % hwnd
		cpXo := cpX, cpYo := cpY
		Random horizontal, 0, 1
		Random maxDelta, 30, 120
		maxDPlus := Round(maxDelta//(movePix.Count()*2))
		;~ SciTEOutput(maxDelta ", " maxDPlus)
		;~ Random velocity, 1, 15

		move := dir ? 1 : -1
		_initMove := true
	}

	Critical, Off
	Critical

	newX := cpX+(move*movePix[aniPos].1)
	If 	(newX < maxXa)
	 || (newX > maxXb)
	 || (newX = cpXo	&& retZPos) {

		dir     := !dir
		move  	:= dir ? 1 : -1
		aniLoop += 0.5
		If (aniPos <= movePix.Count()) {

			If (aniLoop > movePix[aniPos].2) && !retZPos {
				retZPos := true
			} else if (aniLoop > movePix[aniPos].2) && retZPos {
				aniPos  += 1
				aniLoop := 0
				retZPos := false
				maxXa := cpXo - maxDelta + maxDPlus*(aniPos-1)
				maxXb := cpXo + maxDelta - maxDPlus*(aniPos-1)
			}

		}

		if (aniPos > movePix.Count()) {

				GuiControl, MoveDraw, CSReload , % "x" cpXo " y" cpYo
				GuiControl, MoveDraw, CSReload1, % "x" cpXo " y" cpYo
				aniPos		:= 1
				aniLoop 	:= 0
				retZPos 	:= false
				dir       := 1
				move    	:= dir ? 1 : -1
				_initMove := false
				;~ ToolTip, % "cpX: " cpX "`nmove: " move " delta(" move*movePix[aniPos].1 ")" "`naniPos: " aniPos "`naniLoop: " aniLoop, 2000, 400, 3
				return


		}


	}

	cpX += move*movePix[aniPos].1
	GuiControl, MoveDraw, CSReload, % "x" cpX " y" cpY
	GuiControl, MoveDraw, CSReload1, % "x" cpX " y" cpY
	;~ ToolTip, % "cpX: " maxXa " < "  cpXo  " > " maxXb "`n                    " cpX "`nmove: " move " delta(" move*movePix[aniPos].1 ")"
					;~ .  "`naniPos: " aniPos "`naniLoop: " aniLoop "`nretZPos: " retZPos, 2000, 400, 3

	Critical, Off

	If _initMove {
		callfunc := Func("FishMove").Bind(hnwd)
		SetTimer, % callfunc, %  -1 ;*velocity
	}

}
TV_GetInfo(EventInfo)                                                       	{

	If !TV_GetParent(EventInfo) {
		TV_GetText(PText, EventInfo)
		SText := ""
	}	else 	{
		TV_GetText(SText, EventInfo)
		TV_GetText(PText, TV_GetParent(EventInfo))
	}

	RegExMatch(PText, "(.*)\s+\[(.*)\]", match)
	FullFilePath	:= match2 "\" match1
	FilePath     	:= match2 "\"

return {"parent": PText, "child": SText, "fullfilepath": fullFilePath, "filepath": FilePath, "EventInfo": EventInfo}
}
GetLastDirs()                                                                	{                   	;-- loads last folders
	if FileExist(A_ScriptDir "\lastDirs.json") {
		try {
			lastDirs := cJSON.Loads(FileOpen(A_ScriptDir "\lastDirs.json", "r", "UTF-8").Read())
		} catch
			lastDirs := Object()
	} else
		lastDirs := Object()
return lastDirs
}
SaveLastDirs()                                                                {
	global lastDirs

	if (!IsObject(lastDirs) || lastDirs.Count() = 0)
		return

	cJSON.EscapeUnicode := true
	FileOpen(A_ScriptDir "\lastDirs.json", "w", "UTF-8").Write(cJSON.Dump(lastDirs, 1))

}
SetStatCount(now, max, yet, notyet)                                          	{

	max := now >= max ? now : max
	maxLen := Max(StrLen(now), StrLen(max))
	GuiControl,, StatCount, % SubStr("0000000" now, -1*(maxLen-1)) "/" SubStr("0000000" max, -1*(maxLen-1))

	notyet := yet >= notyet ? yet : notyet
	maxLen := Max(StrLen(yet), StrLen(notyet))
	GuiControl,, StatPathCount, % SubStr("0000000" yet, -1*(maxLen-1)) "/" SubStr("0000000" notyet, -1*(maxLen-1))

}
DisEnable(status)                                                           	{
	; use Enable or Disable
	GuiControl, % status, btnDirectoryBrowse
	GuiControl, % status, txtInitialDirectory
	GuiControl, % status, txtSearchString
	GuiControl, % status, btnSearch
}
ControlIsFocused(ControlID)                                                  	{                   	;-- true or false if specified gui control is active or not
	GuiControlGet, FControlID, Focus
	If Instr(FControlID, ControlID)
			return true
return false
}
GetWindowSpot(hWnd)                                                         	{                    	;-- like GetWindowInfo, but faster because it only returns position and sizes
    NumPut(VarSetCapacity(WINDOWINFO, 60, 0), WINDOWINFO)
    DllCall("GetWindowInfo", "Ptr", hWnd, "Ptr", &WINDOWINFO)
    wi := Object()
    wi.X   	:= NumGet(WINDOWINFO, 4	, "Int")
    wi.Y   	:= NumGet(WINDOWINFO, 8	, "Int")
    wi.W  	:= NumGet(WINDOWINFO, 12, "Int") 	- wi.X
    wi.H  	:= NumGet(WINDOWINFO, 16, "Int") 	- wi.Y
    wi.CX	:= NumGet(WINDOWINFO, 20, "Int")
    wi.CY	:= NumGet(WINDOWINFO, 24, "Int")
    wi.CW 	:= NumGet(WINDOWINFO, 28, "Int") 	- wi.CX
    wi.CH  	:= NumGet(WINDOWINFO, 32, "Int") 	- wi.CY
	wi.S   	:= NumGet(WINDOWINFO, 36, "UInt")
    wi.ES 	:= NumGet(WINDOWINFO, 40, "UInt")
	wi.Ac	:= NumGet(WINDOWINFO, 44, "UInt")
    wi.BW	:= NumGet(WINDOWINFO, 48, "UInt")
    wi.BH	:= NumGet(WINDOWINFO, 52, "UInt")
	wi.A    	:= NumGet(WINDOWINFO, 56, "UShort")
    wi.V  	:= NumGet(WINDOWINFO, 58, "UShort")
Return wi
}
SetWindowPos(hWnd, x, y, w, h, hWndInsertAfter := 0, uFlags := 0x40) 		    	{                  		;--works better than the internal command WinMove - why?

	/*  ; https://docs.microsoft.com/en-us/windows/desktop/api/winuser/nf-winuser-setwindowpos

	SWP_NOSIZE                 	:= 0x0001	; Retains the current size (ignores the cx and cy parameters).
	SWP_NOMOVE                 	:= 0x0002	; Retains the current position (ignores X and Y parameters).
	SWP_NOZORDER              	:= 0x0004	; Retains the current Z order (ignores the hWndInsertAfter parameter).
	SWP_NOREDRAW              	:= 0x0008	; Does not redraw changes.
	SWP_NOACTIVATE            	:= 0x0010	; Does not activate the window.
	SWP_DRAWFRAME             	:= 0x0020	; Draws a frame (defined in the window's class description) around the window.
	SWP_FRAMECHANGED          	:= 0x0020	; Applies new frame styles set using the SetWindowLong function.
	SWP_SHOWWINDOW             	:= 0x0040	; Displays the window.
	SWP_HIDEWINDOW            	:= 0x0080	; Hides the window
	SWP_NOCOPYBITS            	:= 0x0100	; Discards the entire contents of the client area.
	SWP_NOOWNERZORDER         	:= 0x0200	; Does not change the owner window's position in the Z order.
	SWP_NOREPOSITION          	:= 0x0200	; Same as the SWP_NOOWNERZORDER flag.
	SWP_NOSENDCHANGING        	:= 0x0400	; Prevents the window from receiving the WM_WINDOWPOSCHANGING message.
	SWP_DEFERERASE             	:= 0x2000	; Prevents generation of the WM_SYNCPAINT message.
	SWP_ASYNCWINDOWPOS        	:= 0x4000	; This prevents the calling thread from blocking its execution while other threads process the request.

	 */

Return DllCall("SetWindowPos", "Ptr", hWnd, "Ptr", hWndInsertAfter, "Int", x, "Int", y, "Int", w, "Int", h, "UInt", uFlags)
}
Edit_BalloonTip(hEdit, Text, Title := "", Show:= false, Icon := 0)   		    	{
    NumPut(VarSetCapacity(EDITBALLOONTIP, 4 * A_PtrSize, 0), EDITBALLOONTIP)
    NumPut(&Title, EDITBALLOONTIP, A_PtrSize    , "Ptr")
    NumPut(&Text , EDITBALLOONTIP, A_PtrSize * 2, "Ptr")
    NumPut(Icon  , EDITBALLOONTIP, A_PtrSize * 3, "UInt")
	SendMessage % (!Show ? 0x1504:0x1503 ), 0, &EDITBALLOONTIP,, % "ahk_id " hEdit ; EM_HIDE OR SHOWBALLOONTIP
Return ErrorLevel
}
LV_RowIsChecked(rowNr, hLV)                                                  	{
	SendMessage, 0x102C, rowNr - 1, 0xF000,, % "ahk_id " hLV   ; 0x102C is LVM_GETITEMSTATE. 0xF000 is LVIS_STATEIMAGEMASK.
return (IsChecked := (ErrorLevel >> 12) - 1)  ; This sets IsChecked to true if RowNumber is checked or false otherwise.
}

RedrawWindow(hwnd=0)                                                        	{
	static RDW_INVALIDATE 	:= 0x0001
	static RDW_ERASE       	:= 0x0004
	static RDW_FRAME       	:= 0x0400
	static RDW_ALLCHILDREN	:= 0x0080
return dllcall("RedrawWindow", "Ptr", hwnd, "Ptr", 0, "Ptr", 0, "UInt", RDW_INVALIDATE | RDW_ERASE | RDW_FRAME | RDW_ALLCHILDREN)
}
WinGetMinMaxState(hwnd)                                                      	{                 		;-- get state if window ist maximized or minimized
	; this function is from AHK-Forum: https://autohotkey.com/board/topic/13020-how-to-maximize-a-childdocument-window/
	; it returns z for maximized("zoomed") or i for minimized("iconic")
	; it's also work on MDI Windows - use hwnd you can get from FindChildWindow()
	zoomed:= DllCall("IsZoomed", "UInt", hwnd)		; Check if maximized
	iconic	:= DllCall("IsIconic"	, "UInt", hwnd)		; Check if minimized
return (zoomed>iconic) ? "z":"i"
}
GetSavedGuiPos(MarginX, MarginY)                                            	{                    	;-- loads last gui position

	gP 	:= Object()

	If (tmp := config.getValue("GuiPos", "Settings"))
		tmp := StrSplit(tmp, "|")

	If isObject(tmp)
		gP.X:=tmp.1, gP.Y:=tmp.2, gP.W:=tmp.3, gP.H:=tmp.4, gP.M:=(tmp.5=1 ? true:false)
	else
		gP.X:=0, gP.Y:=0, gP.W:=1600, gP.H:=1000, 	gP.M	:=false

return gP
}
SaveGuiPos()                                                                 	{
	winMax 	:= Instr(WinGetMinMaxState(hCSGui), "z") ? 1 : 0
	win		:= GetWindowSpot(hCSGui)
	winPos 	:= win.X "|" win.Y "|" win.CW "|" win.CH "|" winMax
	trv	  	:= GetWindowSpot(hTV)
	IniWrite, % winpos	, % A_ScriptDir "\config.ini", Settings, GuiPos
	IniWrite, % trv.CW	, % A_ScriptDir "\config.ini", Settings, TV_Width
}
GetHighlighter(file)                                                        	{
	SplitPath, file,,, extension
	extension := extension ~= "i)(python|py)"             	? "Python"
						:	 extension ~= "i)^(ahk|ahk1|ah1|ahk2|ah2)$" ? "AHK"
						:  extension
return isFunc("Highlight" extension) ? ("Highlight" extension) : ""
}
GetFocusedControlHwnd(hwnd:="A")                                            	{
	ControlGetFocus, FocusedControl, % (hwnd = "A") ? "A" : "ahk_id " hwnd
	ControlGet, FocusedControlId, Hwnd,, %FocusedControl%, % (hwnd = "A") ? "A" : "ahk_id " hwnd
return GetHex(FocusedControlId)
}
GetHex(hwnd)                                                                 	{
return Format("0x{:x}", hwnd)
}
GetDec(hwnd)                                                                 	{
return Format("{:u}", hwnd)
}
listfunc(file)                                                               	{

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
adjHdrs(listView:="")                                                       	{
	Gui, ListView, % listView
	Loop, % LV_GetCount("Col")
		LV_ModifyCol(A_Index, "autoHdr")
	LV_ModifyCol(1,"Integer Left")
return
}
truncate(s, c="50")                                                         	{
return (StrLen(s) > c) ? SubStr(s, 1, c) " (...)" : LTrim(s)
}
GetLastFilesCount(searchpaths:="", extensions:="")                          	{                     ;-- counts last files found in all dirs

	global lastDirs

	if !IsObject(searchPaths)
		searchpaths := GetSearchPaths()

	if !extensions {
		addExtensions := getAdditionalExtensions()
		extensions  	:= getExtensions()
		extensions  	:= extensions (addExtensions ? (extensions ? ",":"") addExtensions : "")
	}

	allDirs := Object()
	allDirs.MaxCount := 0
	allDirs.fType    := Object()
	allDirs.sPaths   := Object()
	allDirs.sPaths.MaxCount := 0
	for each, searchpath in searchPaths
		if isObject(lastDir[searchpath])
			for ftypeNr, fext in StrSplit(extensions, ",") {
				allDirs.fType[fext]                 += lastDirs[searchpath].ftype[fext]
				allDirs.MaxCount  	                += lastDirs[searchpath].ftype[fext]
				allDirs.sPaths[searchpath][fext]  	+= lastDirs[searchpath].ftype[fext]
				allDirs.sPaths[searchpath].MaxCount	+= lastDirs[searchpath].ftype[fext]
			}

return allDirs
}
GetCheckedFileTypes()                                                         {                     ;-- counts checked extensions

	global ftypes

	Gui, Submit, NoHide

	ftypesChecked := 0
	for each, ftype in ftypes {
		GuiControlGet, ischecked,, % "cbx" ftype
		ftypesChecked += ischecked ? 1 : 0
	}

return ftypesChecked
}
GetSearchPaths()                                                              {                    	;-- alle Suchpfade ermitteln
	searchpaths := []
	Gui, ListView, LVSearchDirs
	Loop % LV_GetCount() {
		LV_GetText(fpath, A_Index, 1)
		LV_GetText(fexts, A_Index, 2)
		fpath := RegExReplace(Trim(fpath), "[^\pL\d\-\_\.,;:@+#]+$")
		if InStr(FileExist(fpath), "D")
			searchpaths.Push(fpath)
	}
return searchpaths
}
getExtensions()                                                              	{
	global
return RTrim((cbxAhk ? "ahk,ah2" : "") (cbxTxt ? "txt,": "") (cbxIni ? "ini," : "") (cbxHtml ? "html," : "") (cbxCss ? "css," : "") (cbxPy ? "py," : "") (cbxJs ? "js," : ""), ",")
}
getAdditionalExtensions()                                                    	{
	global txtAdditionalExtensions
	Gui, Submit, NoHide
	AddExtensions := RegExReplace(txtAdditionalExtensions, "[^\w_,]")
	AddExtensions := RegExReplace(AddExtensions, "^,+$")
	AddExtensions := RegExReplace(AddExtensions, "^,+")
	AddExtensions := RegExReplace(AddExtensions, ",+$")
	if (AddExtensions != txtAdditionalExtensions)
		GuiControl,, txtAdditionalExtensions, % AddExtensions
	if (AddExtensions != lastAdditionalExtensions)
		config.setValue("additionalExtensions", "Settings", AddExtensions)
return AddExtensions
}
getExpression(keyword, wholeWord)                                           	{
return (wholeWord) ? "[\s|\W]?" keyword "[\s|\W]" : keyword
}
getRegExOptions(caseSense)                                                  	{
; if casesense is negativ use "i" regexoption for searching searching
return "O" (!caseSense ? "i" : "") ")"
}
GenHighlighterCache(Settings)                                                	{

		if Settings.HasKey("Cache")
			return
		Cache := Settings.Cache := {}

	; Process Colors
		Cache.Colors := Settings.Colors.Clone()

	; Inherit from the Settings array's base
		BaseSettings := Settings
		While (BaseSettings := BaseSettings.Base)
			For Name, Color in BaseSettings.Colors
				If !Cache.Colors.HasKey(Name)
					Cache.Colors[Name] := Color

	; Include the color of plain text
		if !Cache.Colors.HasKey("Plain")
			Cache.Colors.Plain := Settings.FGColor

	; Create a Name->Index map of the colors
		Cache.ColorMap := {}
		For Name, Color in Cache.Colors
			Cache.ColorMap[Name] := A_Index

	; Generate the RTF headers
		RTF := "{\urtf"

	; Color Table
		RTF .= "{\colortbl;"
		For Name, Color in Cache.Colors	{
			RTF .= "\red"    	Color>>16	& 0xFF
			RTF .= "\green" 	Color>>8 	& 0xFF
			RTF .= "\blue"  	Color      	& 0xFF ";"
		}
		RTF .= "}"

	; Font Table
		If Settings.Font	{
			FontTable .= "{\fonttbl{\f0\fmodern\fcharset0 "
			FontTable .= Settings.Font.Typeface
			FontTable .= ";}}"
			RTF .= "\fs" Settings.Font.Size * 2 ; Font size (half-points)
			if Settings.Font.Bold
				RTF .= "\b"
		}

	; Tab size (twips)
		RTF .= "\deftab" GetCharWidthTwips(Settings.Font) * Settings.TabSize
		Cache.RTFHeader := RTF

}
GetCharWidthTwips(Font)                                                     	{

	static Cache := {}

	if Cache.HasKey(Font.Typeface "_" Font.Size "_" Font.Bold)
		return Cache[Font.Typeface "_" font.Size "_" Font.Bold]

	; Calculate parameters of CreateFont
	Height	:= -Round(Font.Size*A_ScreenDPI/72)
	Weight	:= 400+300*(!!Font.Bold)
	Face 	:= Font.Typeface

	; Get the width of "x"
	hDC 	:= DllCall("GetDC", "UPtr", 0)
	hFont 	:= DllCall("CreateFont"
					, "Int", Height 	; _In_ int       	  nHeight,
					, "Int", 0         	; _In_ int       	  nWidth,
					, "Int", 0        	; _In_ int       	  nEscapement,
					, "Int", 0        	; _In_ int       	  nOrientation,
					, "Int", Weight ; _In_ int        	  fnWeight,
					, "UInt", 0     	; _In_ DWORD   fdwItalic,
					, "UInt", 0     	; _In_ DWORD   fdwUnderline,
					, "UInt", 0     	; _In_ DWORD   fdwStrikeOut,
					, "UInt", 0     	; _In_ DWORD   fdwCharSet, (ANSI_CHARSET)
					, "UInt", 0     	; _In_ DWORD   fdwOutputPrecision, (OUT_DEFAULT_PRECIS)
					, "UInt", 0     	; _In_ DWORD   fdwClipPrecision, (CLIP_DEFAULT_PRECIS)
					, "UInt", 0     	; _In_ DWORD   fdwQuality, (DEFAULT_QUALITY)
					, "UInt", 0     	; _In_ DWORD   fdwPitchAndFamily, (FF_DONTCARE|DEFAULT_PITCH)
					, "Str", Face   	; _In_ LPCTSTR  lpszFace
					, "UPtr")
	hObj := DllCall("SelectObject", "UPtr", hDC, "UPtr", hFont, "UPtr")
	VarSetCapacity(SIZE, 8, 0)
	DllCall("GetTextExtentPoint32", "UPtr", hDC, "Str", "x", "Int", 1, "UPtr", &SIZE)
	DllCall("SelectObject", "UPtr", hDC, "UPtr", hObj, "UPtr")
	DllCall("DeleteObject", "UPtr", hFont)
	DllCall("ReleaseDC", "UPtr", 0, "UPtr", hDC)

	; Convert to twpis
	Twips := Round(NumGet(SIZE, 0, "UInt")*1440/A_ScreenDPI)
	Cache[Font.Typeface "_" Font.Size "_" Font.Bold] := Twips
	return Twips
}
EscapeRTF(Code)                                                             	{
	for each, Char in ["\", "{", "}", "`n"]
		Code := StrReplace(Code, Char, "\" Char)
return StrReplace(StrReplace(Code, "`t", "\tab "), "`r")
}
GetKeywordFromCaret(rc) 	                                                  	{

	; https://autohotkey.com/boards/viewtopic.php?p=180369#p180369
		static Buffer
		IsUnicode := !!A_IsUnicode

		;rc := this.RichCode
		sel := rc.Selection

	; Get the currently selected line
		LineNum := rc.SendMsg(0x436, 0, sel[1]) ; EM_EXLINEFROMCHAR

	; Size a buffer according to the line's length
		Length := rc.SendMsg(0xC1, sel[1], 0) ; EM_LINELENGTH
		VarSetCapacity(Buffer, Length << !!A_IsUnicode, 0)
		NumPut(Length, Buffer, "UShort")

	; Get the text from the line
		rc.SendMsg(0xC4, LineNum, &Buffer) ; EM_GETLINE
		lineText := StrGet(&Buffer, Length)

	; Parse the line to find the word
		LineIndex := rc.SendMsg(0xBB, LineNum, 0) ; EM_LINEINDEX
		RegExMatch(SubStr(lineText, 1, sel[1]-LineIndex), "[#\w]+$", Start)
		RegExMatch(SubStr(lineText, sel[1]-LineIndex+1), "^[#\w]+", End)

return Start . End
}
Scite_CurrentWord()                                                         	{
	sci := GV_ST_SciEdit1
	StartingPos := sci.GetCurrentPos() ; store current position
	; Select current 'word'
	sci.SetSelectionStart(sci.WordStartPosition(StartingPos, 1))
	sci.SetSelectionEnd(sci.WordEndPosition(StartingPos, 1))
	; UTF-8 jiggery-pokery begins...
	SelLength := Sci.GetSelText() - 1
	VarSetCapacity(SelText, SelLength, 0)
	Sci.GetSelText(0, &SelText)
	thisWord := StrGet(&SelText, SelLength, "UTF-8")
	; UTF-8 jiggery-pokery ends...
	Sci.SetSelectionStart(StartingPos) ; clear selection start
	Sci.SetSelectionEnd(StartingPos) ; clear selection end
	Return thisWord
}
CB_ItemExist(cbhwnd, item)                                                  	{

	ControlGet, cbList, List,,, % "ahk_id " cbhwnd
	For each, cbitem in StrSplit(cbList, "`n")
		If (cbitem = item)
			return true

return false
}
GetAppImagePath(appname)                                                      {                   	;-- Installationspfad eines Programmes

	headers:= {	"DISPLAYNAME"                  	: 1
					, 	"VERSION"                         	: 2
					, 	"PUBLISHER"             	         	: 3
					, 	"PRODUCTID"                    	: 4
					, 	"REGISTEREDOWNER"        	: 5
					, 	"REGISTEREDCOMPANY"    	: 6
					, 	"LANGUAGE"                     	: 7
					, 	"SUPPORTURL"                    	: 8
					, 	"SUPPORTTELEPHONE"       	: 9
					, 	"HELPLINK"                        	: 10
					, 	"INSTALLLOCATION"          	: 11
					, 	"INSTALLSOURCE"             	: 12
					, 	"INSTALLDATE"                  	: 13
					, 	"CONTACT"                        	: 14
					, 	"COMMENTS"                    	: 15
					, 	"IMAGE"                            	: 16
					, 	"UPDATEINFOURL"            	: 17}

   appImages := GetAppsInfo({mask: "IMAGE", offset: A_PtrSize*(headers["IMAGE"] - 1) })
   Loop, Parse, appImages, "`n"
	If Instr(A_loopField, appname)
		return A_loopField

return ""
}
GetAppsInfo(infoType)                                                         {

	static CLSID_EnumInstalledApps := "{0B124F8F-91F0-11D1-B8B5-006008059382}"
        , IID_IEnumInstalledApps     	:= "{1BC752E1-9046-11D1-B8B3-006008059382}"

        , DISPLAYNAME            	:= 0x00000001
        , VERSION                    	:= 0x00000002
        , PUBLISHER                  	:= 0x00000004
        , PRODUCTID                	:= 0x00000008
        , REGISTEREDOWNER    	:= 0x00000010
        , REGISTEREDCOMPANY	:= 0x00000020
        , LANGUAGE                	:= 0x00000040
        , SUPPORTURL               	:= 0x00000080
        , SUPPORTTELEPHONE  	:= 0x00000100
        , HELPLINK                     	:= 0x00000200
        , INSTALLLOCATION     	:= 0x00000400
        , INSTALLSOURCE         	:= 0x00000800
        , INSTALLDATE              	:= 0x00001000
        , CONTACT                  	:= 0x00004000
        , COMMENTS               	:= 0x00008000
        , IMAGE                        	:= 0x00020000
        , READMEURL                	:= 0x00040000
        , UPDATEINFOURL        	:= 0x00080000

   pEIA := ComObjCreate(CLSID_EnumInstalledApps, IID_IEnumInstalledApps)

   while DllCall(NumGet(NumGet(pEIA+0) + A_PtrSize*3), Ptr, pEIA, PtrP, pINA) = 0  {
      VarSetCapacity(APPINFODATA, size := 4*2 + A_PtrSize*18, 0)
      NumPut(size, APPINFODATA)
      mask := infoType.mask
      NumPut(%mask%, APPINFODATA, 4)

      DllCall(NumGet(NumGet(pINA+0) + A_PtrSize*3), Ptr, pINA, Ptr, &APPINFODATA)
      ObjRelease(pINA)
      if !(pData := NumGet(APPINFODATA, 8 + infoType.offset))
         continue
      res .= StrGet(pData, "UTF-16") . "`n"
      DllCall("Ole32\CoTaskMemFree", Ptr, pData)  ; not sure, whether it's needed
   }
   Return res
}
SelectFolderEx(StartingFolder:="", Prompt:="", OwnerHwnd:=0, OkBtnLabel:="", comboList:="", desiredDefault:=1, comboLabel:="", CustomPlaces:="", pickFoldersOnly:=1) {
; ==================================================================================================================================
; Shows a dialog to select a folder.
; Depending on the OS version the function will use either the built-in FileSelectFolder command (XP and previous)
; or the Common Item Dialog (Vista and later).
;
; Parameter:
;     StartingFolder -  the full path of a folder which will be preselected.
;     Prompt         -  a text used as window title (Common Item Dialog) or as text displayed withing the dialog.
;     ----------------  Common Item Dialog only:
;     OwnerHwnd      -  HWND of the Gui which owns the dialog. If you pass a valid HWND the dialog will become modal.
;     BtnLabel       -  a text to be used as caption for the apply button.
;     comboList      -  a string with possible drop-down options, separated by `n [new line]
;     desiredDefault -  the default selected drop-down row
;     comboLabel     -  the drop-down label to display
;     CustomPlaces   -  custom directories that will be displayed in the left pane of the dialog; missing directories will be omitted; a string separated by `n [newline]
;     pickFoldersOnly - boolean option [0, 1]
;
;  Return values:
;     On success the function returns an object with the full path of the selected/file folder
;     and combobox selected [if any]; otherwise it returns an empty string.
;
; MSDN:
;     Common Item Dialog -> msdn.microsoft.com/en-us/library/bb776913%28v=vs.85%29.aspx
;     IFileDialog        -> msdn.microsoft.com/en-us/library/bb775966%28v=vs.85%29.aspx
;     IShellItem         -> msdn.microsoft.com/en-us/library/bb761140%28v=vs.85%29.aspx
; ==================================================================================================================================
; Source https://www.autohotkey.com/boards/viewtopic.php?f=6&t=18939
; by «just me»
; modified by Marius Șucan on: vendredi 8 mai 2020
; to allow ComboBox and CustomPlaces
;
; options flags
; FOS_OVERWRITEPROMPT  = 0x2,
; FOS_STRICTFILETYPES  = 0x4,
; FOS_NOCHANGEDIR  = 0x8,
; FOS_PICKFOLDERS  = 0x20,
; FOS_FORCEFILESYSTEM  = 0x40,
; FOS_ALLNONSTORAGEITEMS  = 0x80,
; FOS_NOVALIDATE  = 0x100,
; FOS_ALLOWMULTISELECT  = 0x200,
; FOS_PATHMUSTEXIST  = 0x800,
; FOS_FILEMUSTEXIST  = 0x1000,
; FOS_CREATEPROMPT  = 0x2000,
; FOS_SHAREAWARE  = 0x4000,
; FOS_NOREADONLYRETURN  = 0x8000,
; FOS_NOTESTFILECREATE  = 0x10000,
; FOS_HIDEMRUPLACES  = 0x20000,
; FOS_HIDEPINNEDPLACES  = 0x40000,
; FOS_NODEREFERENCELINKS  = 0x100000,
; FOS_OKBUTTONNEEDSINTERACTION  = 0x200000,
; FOS_DONTADDTORECENT  = 0x2000000,
; FOS_FORCESHOWHIDDEN  = 0x10000000,
; FOS_DEFAULTNOMINIMODE  = 0x20000000,
; FOS_FORCEPREVIEWPANEON  = 0x40000000,
; FOS_SUPPORTSTREAMABLEITEMS  = 0x80000000

; IFileDialog vtable offsets
; 0   QueryInterface
; 1   AddRef
; 2   Release
; 3   Show
; 4   SetFileTypes
; 5   SetFileTypeIndex
; 6   GetFileTypeIndex
; 7   Advise
; 8   Unadvise
; 9   SetOptions
; 10  GetOptions
; 11  SetDefaultFolder
; 12  SetFolder
; 13  GetFolder
; 14  GetCurrentSelection
; 15  SetFileName
; 16  GetFileName
; 17  SetTitle
; 18  SetOkButtonLabel
; 19  SetFileNameLabel
; 20  GetResult
; 21  AddPlace
; 22  SetDefaultExtension
; 23  Close
; 24  SetClientGuid
; 25  ClearClientData
; 26  SetFilter

   Static OsVersion := DllCall("GetVersion", "UChar")
        , IID_IShellItem := 0
        , InitIID := VarSetCapacity(IID_IShellItem, 16, 0)
                  & DllCall("Ole32.dll\IIDFromString", "WStr", "{43826d1e-e718-42ee-bc55-a1e261c37bfe}", "Ptr", &IID_IShellItem)
        , Show := A_PtrSize * 3
        , SetOptions := A_PtrSize * 9
        , SetFolder := A_PtrSize * 12
        , SetTitle := A_PtrSize * 17
        , SetOkButtonLabel := A_PtrSize * 18
        , GetResult := A_PtrSize * 20
        , ComDlgObj := {COMDLG_FILTERSPEC: ""}

   SelectedFolder := ""
   If (OsVersion<6)
   {
      ; IFileDialog requires Win Vista+, so revert to FileSelectFolder
      FileSelectFolder, SelectedFolder, *%StartingFolder%, 3, %Prompt%
      Return SelectedFolder
   }

   OwnerHwnd := DllCall("IsWindow", "Ptr", OwnerHwnd, "UInt") ? OwnerHwnd : 0
   If !(FileDialog := ComObjCreate("{DC1C5A9C-E88A-4dde-A5A1-60F82A20AEF7}", "{42f85136-db7e-439c-85f1-e4075d135fc8}"))
      Return ""

   VTBL := NumGet(FileDialog + 0, "UPtr")
   dialogOptions := 0x8 | 0x800  ;  FOS_NOCHANGEDIR | FOS_PATHMUSTEXIST
   dialogOptions |= (pickFoldersOnly=1) ? 0x20 : 0x1000    ; FOS_PICKFOLDERS : FOS_FILEMUSTEXIST

   DllCall(NumGet(VTBL + SetOptions, "UPtr"), "Ptr", FileDialog, "UInt", dialogOptions, "UInt")
   If StartingFolder
   {
      If !DllCall("Shell32.dll\SHCreateItemFromParsingName", "WStr", StartingFolder, "Ptr", 0, "Ptr", &IID_IShellItem, "PtrP", FolderItem)
         DllCall(NumGet(VTBL + SetFolder, "UPtr"), "Ptr", FileDialog, "Ptr", FolderItem, "UInt")
   }

   If Prompt
      DllCall(NumGet(VTBL + SetTitle, "UPtr"), "Ptr", FileDialog, "WStr", Prompt, "UInt")
   If OkBtnLabel
      DllCall(NumGet(VTBL + SetOkButtonLabel, "UPtr"), "Ptr", FileDialog, "WStr", OkBtnLabel, "UInt")

   If CustomPlaces
   {
      Loop, Parse, CustomPlaces, `n
      {
          If InStr(FileExist(A_LoopField), "D")
          {
             foo := 1, Directory := A_LoopField
             DllCall("Shell32.dll\SHParseDisplayName", "UPtr", &Directory, "Ptr", 0, "UPtrP", PIDL, "UInt", 0, "UInt", 0)
             DllCall("Shell32.dll\SHCreateShellItem", "Ptr", 0, "Ptr", 0, "UPtr", PIDL, "UPtrP", IShellItem)
             ObjRawSet(ComDlgObj, IShellItem, PIDL)
             ; IFileDialog::AddPlace method
             ; https://msdn.microsoft.com/en-us/library/windows/desktop/bb775946(v=vs.85).aspx
             DllCall(NumGet(NumGet(FileDialog+0)+21*A_PtrSize), "UPtr", FileDialog, "UPtr", IShellItem, "UInt", foo)
          }
      }
   }

   If (comboList && comboLabel)
   {
      Try If ((FileDialogCustomize := ComObjQuery(FileDialog, "{e6fdd21a-163f-4975-9c8c-a69f1ba37034}")))
      {
         groupId := 616 ; arbitrarily chosen IDs
         comboboxId := 93270
         DllCall(NumGet(NumGet(FileDialogCustomize+0)+26*A_PtrSize), "Ptr", FileDialogCustomize, "UInt", groupId, "WStr", comboLabel) ; IFileDialogCustomize::StartVisualGroup
         DllCall(NumGet(NumGet(FileDialogCustomize+0)+6*A_PtrSize), "Ptr", FileDialogCustomize, "UInt", comboboxId) ; IFileDialogCustomize::AddComboBox
         ; DllCall(NumGet(NumGet(FileDialogCustomize+0)+19*A_PtrSize), "Ptr", FileDialogCustomize, "UInt", comboboxId, "UInt", itemOneId, "WStr", "Current folder") ; IFileDialogCustomize::AddControlItem

         entriesArray := []
         Loop, Parse, comboList,`n
         {
             Random, varA, 2, 900
             Random, varB, 2, 900
             thisID := varA varB
             If A_LoopField
             {
                If (A_Index=desiredDefault)
                   desiredIDdefault := thisID

                entriesArray[thisId] := A_LoopField
                DllCall(NumGet(NumGet(FileDialogCustomize+0)+19*A_PtrSize), "Ptr", FileDialogCustomize, "UInt", comboboxId, "UInt", thisID, "WStr", A_LoopField)
             }
         }

         DllCall(NumGet(NumGet(FileDialogCustomize+0)+25*A_PtrSize), "Ptr", FileDialogCustomize, "UInt", comboboxId, "UInt", desiredIDdefault) ; IFileDialogCustomize::SetSelectedControlItem
         DllCall(NumGet(NumGet(FileDialogCustomize+0)+27*A_PtrSize), "Ptr", FileDialogCustomize) ; IFileDialogCustomize::EndVisualGroup
      }

   }

   If !DllCall(NumGet(VTBL + Show, "UPtr"), "Ptr", FileDialog, "Ptr", OwnerHwnd, "UInt")
   {
      If !DllCall(NumGet(VTBL + GetResult, "UPtr"), "Ptr", FileDialog, "PtrP", ShellItem, "UInt")
      {
         GetDisplayName := NumGet(NumGet(ShellItem + 0, "UPtr"), A_PtrSize * 5, "UPtr")
         If !DllCall(GetDisplayName, "Ptr", ShellItem, "UInt", 0x80028000, "PtrP", StrPtr) ; SIGDN_DESKTOPABSOLUTEPARSING
            SelectedFolder := StrGet(StrPtr, "UTF-16"), DllCall("Ole32.dll\CoTaskMemFree", "Ptr", StrPtr)

         ObjRelease(ShellItem)
         if (FileDialogCustomize)
         {
            if (DllCall(NumGet(NumGet(FileDialogCustomize+0)+24*A_PtrSize), "Ptr", FileDialogCustomize, "UInt", comboboxId, "UInt*", selectedItemId) == 0)
            { ; IFileDialogCustomize::GetSelectedControlItem
               if selectedItemId
                  thisComboSelected := entriesArray[selectedItemId]
            }
         }
      }
   }
   If (FolderItem)
      ObjRelease(FolderItem)

   if (FileDialogCustomize)
      ObjRelease(FileDialogCustomize)

   ObjRelease(FileDialog)
   r := []
   r.SelectedDir := SelectedFolder
   r.SelectedCombo := thisComboSelected
   Return r
}

;}

#Include %A_ScriptDir%\Classes\class_Config.ahk
#Include %A_ScriptDir%\Classes\Highlighters\AHK.ahk
#Include %A_ScriptDir%\Classes\Highlighters\CSS.ahk
#Include %A_ScriptDir%\Classes\Highlighters\JS.ahk
#Include %A_ScriptDir%\Classes\Highlighters\HTML.ahk
#Include %A_ScriptDir%\Classes\Highlighters\Python.ahk
#Include %A_ScriptDir%\Classes\class_RichCode.ahk
#Include %A_ScriptDir%\Classes\class_WinEvents.ahk
#Include %A_ScriptDir%\Classes\class_cJSON.ahk
#Include %A_ScriptDir%\Includes\SciTEOutput.ahk





