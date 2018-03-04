<div align="center" style="color:#1e2327"><h1>AHK-CodeSearch</h1></div>
<div align="center" style="color:#1e2327"><h5>Original code from fishgeek / modified last on 04.03.2018 (V1.2) from Ixiko</h5></div>

<div align="center" style="color:#000000"><h4>Original text from fischgeek's repository</h4></div>

<div align="center">
Remember that bit of code you wrote, but can't remember exactly where you wrote it?
Try using this tool to target a directory and search for a keyword inside of your code files.<br>
</div>
<br><br>


my version look'a'like:

<div align="center"><img src="https://github.com/Ixiko/AHK-CodeSearch/blob/master/assets/Screenshot.png" alt="modified original AHK-CodeSearch Screenshot - Ixiko"></div>


															   		
1. Ready to enter the search string right after the start
2. pressing Enter after entering the search string starts the search immediately
3. the buttons R, W, C now show their long name																	V1.1 - 03.03.2018
4. the window displays the number of files read so far and the number of digits found during the search process
5. Font size and window size is adapted to 4k monitors (Size of Gui is huge - over 3000 pixel width) - at the moment, no resize or
	any settings for the size of the contents is possible - i'm sorry for that
					V1.2 - 04.03.2018
6. Stop/Resume Button is added - so the process can be interrupted even to start a new search
	6.a. from fischgeek Todo -  Find an icon - i take your Github-Logo and it looks great!
	
	
Fischgeeks TODO:
	- Add ability to double-click open a file to that line number -> I can still do that<br>
	- Add progress bar - nearly SOLVED -> I integrated counters<br>
	- Add right-click context menu<br>
	- Add option to open file location<br>
	- Add Anchor() - THIS IS A MUST BE - I'm just pressing it<br>
	- Account for additional extensions - you mean .py?<br>
		...indexing? I currently have 13.000 Autohotkey scripts on the hard drive and your program is fast enough for me<br>
	- Possibly add an extension manager?<br>
	- Find an icon - SOLVED -> see above<br>
	- Add pre-search checks (extension selection, directory)<br>
	- Add finished notification (statusbar?) -> SOLVED - I used the window title<br>
	- Add auto saving of selected options and filters<br>
