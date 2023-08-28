class Config {

	Path := A_ScriptDir "\config.ini"

	setValue(value, key, mainkey:="settings") {
    	IniWrite, % value, % this.Path, % mainkey, % key
	}

	getValue(key, mainkey:="settings", default:=0) {
		IniRead, value, % this.Path, % mainkey, % key, % default
		If Instr(value, "Error")
			value := 0
	return value
	}

}