/*  
	DB2Edit installation script
*/

if 0 then SIGNAL TEst;

call RxFuncAdd "SysLoadFuncs", "RexxUtil", "SysLoadFuncs"
call SysLoadFuncs

nok = RxFuncAdd("RxExtra", "RxExtras", "RxExtra");
rc  = RxExtra("LOAD");
rc  = RxQueryCountryInfo( "Countrydata." )
CountryCode = Countrydata.Country_Code;
if CountryCode = 40 ,	/* Schweiz	*/
 | CountryCode = 41 ,
 | CountryCode = 43 ,
 | CountryCode = 49  then;do;YLang.Ger = 1;YLang.Eng = 0;end;
                     else;do;YLang.Eng = 1;YLang.Ger = 0;end;

DBE_Dir = directory();		/* get DB2Edit home dir		*/

/* ----------------------------------------------------		*/
/* Check if it is really the DB2Edit-dir:			*/
/* ----------------------------------------------------		*/
ok = SysFileTree("DB2Edit.exe", "files.");
if files.0 <> 1 then do
   say "(cannot find DB2Edit.exe)";
   say "To install the DB2Edit product you must run this"
   say "install.cmd from the directory, where the DB2Edit-files"
   say "are located."
   exit;
end;

/* ----------------------------------------------------		*/
/* Create FOLDER object for DB2Edit:				*/
/* ----------------------------------------------------		*/

FolderID = "<DB2Edit Objects>";

ok = SysCreateObject(	"WPFolder",	,
			"DB2Edit",	,
			"<WP_DESKTOP>",		,
			"OBJECTID="FolderID";ICONFILE="DBE_Dir"\Folder1.ico;ICONFILE2="DBE_Dir"\Folder2.ico",	,
			"Replace"		,
		    );

if ok then
   say "Folder-object successfully created";
else;
   say "Error creating Folder-object: Code="ok;

/* ----------------------------------------------------		*/
/* Create program object:					*/
/* ----------------------------------------------------		*/

ok = SysCreateObject(	"WpProgram",					,
			"DB2Edit"||"0D0A"x||"The DB2-admin's Swiss Army Knife",		,
			FolderID,					,
			"EXENAME="directory()"\DB2Edit.exe;ICONFILE="DBE_Dir"\Program.ico;"||	,
			"STARTUPDIR="directory()"\",			,
			"Replace"		,
		    );

if ok then
   say "Program-object successfully created";
else;
   say "Error creating program-object: Code="ok;



Test:

ok = directory(DBE_dir);	/* restore home dir		*/


say ""
if YLang.Ger then do
/* ---------------------- Deutsch: -----------------------------	*/
say "Herzlichen GlÅckwunsch! Sie haben DB2Edit erfolgreich";
say "installiert! Um das Programm zu starten, îffnen Sie nun den";
say "DB2Edit-Ordner, der soeben auf Ihrem Desktop angelegt";
say "wurde, und doppelklicken Sie auf das Programm-Icon.";
end;

if YLang.Eng then do
/* ---------------------- Englisch: -----------------------------	*/
say "Congratulation! You have successfully installed the "
say "DB2Edit program. To start using it, please open the"
say "DB2Edit-folder, which has just been created on your"
say "desktop and doubleclick on the program icon."
say ""
say "Have fun!";
say "";
end;

exit;
