/*:VRX         Main
*/
/*  Main
*/
Main:
/*  Process the arguments.
    Get the parent window.
*/
    parse source . calledAs .
    parent = ""
    argCount = arg()
    argOff = 0
    if( calledAs \= "COMMAND" )then do
        if argCount >= 1 then do
            parent = arg(1)
            argCount = argCount - 1
            argOff = 1
        end
    end; else do
        call VROptions 'ImplicitNames'
    end
    InitArgs.0 = argCount
    if( argCount > 0 )then do i = 1 to argCount
        InitArgs.i = arg( i + argOff )
    end
    drop calledAs argCount argOff

/*  Load the windows
*/
    call VRInit
    parse source . . spec
    _VREPrimaryWindowPath = ,
        VRParseFileName( spec, "dpn" ) || ".VRW"
    _VREPrimaryWindow = ,
        VRLoad( parent, _VREPrimaryWindowPath )
    drop parent spec
    if( _VREPrimaryWindow == "" )then do
        call VRMessage "", "Cannot load window:" VRError(), ,
            "Error!"
        _VREReturnValue = 32000
        signal _VRELeaveMain
    end

/*  Process events
*/
    call Init
    signal on halt
    do while( \ VRGet( _VREPrimaryWindow, "Shutdown" ) )
        _VREEvent = VREvent()
        interpret _VREEvent
    end
_VREHalt:
    _VREReturnValue = Fini()
    call VRDestroy _VREPrimaryWindow
_VRELeaveMain:
    call VRFini
exit _VREReturnValue

VRLoadSecondary:
    __vrlsWait = abbrev( 'WAIT', translate(arg(2)), 1 )
    if __vrlsWait then do
        call VRFlush
    end
    __vrlsHWnd = VRLoad( VRWindow(), VRWindowPath(), arg(1) )
    if __vrlsHWnd = '' then signal __vrlsDone
    if __vrlsWait \= 1 then signal __vrlsDone
    call VRSet __vrlsHWnd, 'WindowMode', 'Modal' 
    __vrlsTmp = __vrlsWindows.0
    if( DataType(__vrlsTmp) \= 'NUM' ) then do
        __vrlsTmp = 1
    end
    else do
        __vrlsTmp = __vrlsTmp + 1
    end
    __vrlsWindows.__vrlsTmp = VRWindow( __vrlsHWnd )
    __vrlsWindows.0 = __vrlsTmp
    do while( VRIsValidObject( VRWindow() ) = 1 )
        __vrlsEvent = VREvent()
        interpret __vrlsEvent
    end
    __vrlsTmp = __vrlsWindows.0
    __vrlsWindows.0 = __vrlsTmp - 1
    call VRWindow __vrlsWindows.__vrlsTmp 
    __vrlsHWnd = ''
__vrlsDone:
return __vrlsHWnd

/*:VRX         CN_Columns_BeginEdit
*/
CN_Columns_BeginEdit: 

/*  !TabName  is set
    hndTble.  ebenso ('Tabelle (Stem) der Field-Handles')

*/

/* wird aus LB_Tables_DoubleClick (VrCreateObject) angesprungen  */

/* Zuvor abprÅfen, ob noch ein alter Update-Vorgang fÅr diesen Record offen ist:   */

if VRGet("PB_Upd_CurRow", "Enabled", 1 ) then do
   if VRInfo("Record") <> VRGet("PB_Upd_CurRow", "UserData") then do

      But = VRMessage( VRWindow(), "Your current field-edit has not been processed by an 'Update Current Row'-request."||  ,
                           "0D0A"x||"Do you want to have it processed right now?", "Please tell me...",  ,,
                           "ButtonsYNC."    ,
                     );

      if But = 3 then do;
           ok = VRMethod("CN_Columns", "CloseEdit");
           YEdit.KeyCols.0 = 0;   /* Primary Key-Columns einer sich im Update befindenden Table       */
           RETURN -1;
      end;

      if But = 1 then
         Call PB_Upd_CurRow_Click;  /* Pending Update nachholen        */

   end;
end;

/* ------------ hier geht's los: ------------------------------------  */

hndRec = VRInfo("Record");  if hndRec = "" then do;ok = VRMethod("CN_Columns", "CloseEdit");RETURN -1;end;  /* dann wurde ein Caption Text versucht zu editieren */
hndFld = VRInfo("Field");

hndTble.OldData  = VRMethod("CN_Columns", "GetFieldData", hndRec, hndFld );

ok = VRSet("PB_Upd_CurRow", "UserData", hndRec);    /* Verankern THIS record am Update-Button   */

/* Testen: First Time around here?      */

if YEdit.KeyCols.0 = 0 then do
   /* dann mÅssen zunÑchst die Primary-Key-Columns ermittelt werden (f. die single-WHERE-Clause des UPDATE-Statements)  */

/* ---------------------------- ZGet_PrimKeyCols: ------------------------- */
SelectStatement = ,
  "select ColNames from syscat.indexes"  ,
  " where tabname = '"translate(!TabName)"'"    ,
  "   and UniqueRule in ('P', 'U')";

s1 = space(SelectStatement);
Call Xsay "SelectStatement="SelectStatement;
call sqlexec "PREPARE s1 FROM :s1";     if sqlca.sqlcode<>0 then Call XSay "Error Prepare, sqlcode="sqlca.sqlcode;
call sqlexec "DECLARE c1 CURSOR FOR s1";if sqlca.sqlcode<>0 then Call XSay "Error Declare, sqlcode="sqlca.sqlcode;
call sqlexec "OPEN  c1";                if sqlca.sqlcode<>0 then Call XSay "Error Open, sqlcode="sqlca.sqlcode;

   /* es darf nur 1 geben:             */
   call sqlexec "FETCH c1 INTO :ColNames  :IDummy ";
            
   if sqlca.sqlcode = 0 then do
      /* ----------------------------------         */
      /* ColNames: '+Colname1+Colname2+....         */
      /* ----------------------------------         */

      ColNames = strip(Translate(ColNames, " ", "+"));
      say "ColNames="ColNames;

      /* ---------------------------------          */
      /* Umsetzen ColName => Field-Handle:          */
      /* ---------------------------------          */
      WhereKlaus = "WHERE ";
      do i = 1 to words(ColNames)
         !ColName = word(ColNames,i);

         /* aufsuchen Key-ColName in Field-Handle-Table:        */
         do j = 1 to hndTble.0
            if !ColName = VRMethod("CN_Columns", "GetFieldAttr", hndTble.j, "Title" ) then do
               KeyData = VRMethod("CN_Columns", "GetFieldData", hndRec, hndTble.j );
               Call Xsay "Found unique-key-column "!ColName" with current value="KeyData;
               LEAVE;
            end;
         end;
         if j > hndTble.0 then do
            say "SysFail: KeyColumn "!ColName" nicht als Field-Handle gefunden; bitte benachrichtigen Sie den techn. Service unter: nezzo@gmx.net, Subject: DB2Edit: Key Column has no Field-Handle";
            LEAVE;
         end;
         /* jetzt WHERE-Klausel fortschreiben:        */
         WhereKlaus = WhereKlaus !ColName "=" KeyData "AND"
         YEdit.KeyCols.i = !ColName hndTble.j;        /*    merk dir sowohl Col-Name als auch Field-Handle  */
      end;
      /* zum Schluss das letzte AND wegknipsen:       */
      WhereKlaus = left(WhereKlaus, length(WhereKlaus)-3);  

      YEdit.KeyCols.0 = i-1;

      hndTble.UpdWhere = WhereKlaus;    Drop WhereKlaus;

      say "Update-WhereKlausel="hndTble.UpdWhere;

   end;
   else;do
      /* der FETCH ist fehlgeschlagen:                */
      if sqlca.sqlcode = 100 then do
         ok = VRMessage( VRWindow(), "The table "!TabName" cannot be updated, because there is no unique index for the table."||"0D0A"x  ,
                                   ||"A unique index is neccessary in order to restrict the requested update of the current row to exactly only that row.",  ,
                                     "Update impossible",    ,
                       );
         ok = VRSet("PB_Upd_CurRow", "Enabled", 0 );     /* kein Row-Update mîglich   */
      end;
      else;do
         /* anderer Fehler:      */
         Call Xsay sqlca.sqlcode" ("sqlca.sqlerrmc")";
      end;
   end;
   call sqlexec "CLOSE c1";

end;
else;do
   NOP;   

end;

return;

/*:VRX         CN_Columns_ContextMenu
*/
CN_Columns_ContextMenu: 

ok = VRSet("MM_Upd_DoTheUpdate", "Enabled", VRGet("PB_Upd_CurRow", "Enabled") );

ok = VRMethod("MM_Update", "PopUp");

say "OK="ok;

return;

/*:VRX         CN_Columns_EndEdit
*/
CN_Columns_EndEdit: Procedure Expose        ,
                                hndTble.    ,
                                FlgTble.    ,
                                hndRec hndFld;

/* wird aus LB_Tables_DoubleClick (VRCreateObject) angesprungen  */

Cancelled = VRInfo("Cancelled");
If Cancelled then do
   Call XSay "Field editing cancelled";
   RETURN -1;
end;

if hndRec = VRInfo("Record") then
   NOP; 
else;do
   if 0 then say "Sysfail - cannot occur: hndRec differs in CN_Columns_BeginEdit / CN_Columns_EndEdit";
   /* DOCH! dieser Fall tritt immer auf, wenn der User im 'Pending Update: ?' den Cancel-Button geklickt hat!   */
   /* Dann soll der User den pending update noch normal ausfÅhren kînnen    */
   RETURN -1;
end;

if hndRec = "" then RETURN -1;

hndFld = VRInfo("Field");

hndTble.NewData = VRMethod("CN_Columns", "GetFieldData", hndRec, hndFld );
say "NewData="hndTble.NewData;

If hndTble.NewData = hndTble.OldData then do
   Call XSay "Field data is unchanged - no update of this column";
   RETURN -1;
end;

/* Aufsuchen zugehîrigen Field-Handle zu der upgedateten Column:    */

do i = 1 to hndTble.0
   if hndTble.i = hndFld then do
      !ColName = VRMethod("CN_Columns", "GetFieldAttr", hndFld, "Title" );
      Call Xsay "Column "!ColName" is about to be updated";
      FlgTble.i = "U";
      ok = VRSet("PB_Upd_CurRow", "Enabled", 1 );     /* ab jetzt ist Row-Update mîglich   */
      LEAVE;
   end;
end;
if i > hndTble.0 then
   say "SysFail: Kein matching Field-Handle gefunden; bitte benachrichtigen Sie den techn. Service unter: nezzo@gmx.net, Subject: DB2Edit: no matching column";

return;

/*:VRX         Combo_DBNames_Change
*/
Combo_DBNames_Change: 
return;

/*:VRX         Combo_DBNames_LostFocus
*/
Combo_DBNames_LostFocus: 

YGlob.DBName = ZSet_DBName("FROMCOMBO");

return

/*:VRX         DoTheSQL
*/
DoTheSQL: 

/*** --------------------------------------------------------
 *** DoTheSQL: Prepare + AusfÅhren SQL-STatement:
 *** --------------------------------------------------------    */

SQL     = arg(1);
What    = arg(2);
Statmnt = arg(3);       /* optional, falls s1 schon belegt      */

if Statmnt = "" then Statmnt = "s1";

   call sqlexec "PREPARE "Statmnt" from :"SQL;
   if sqlca.sqlcode <> 0 then do
      z = "!SQL_Stmt="SQL;  interpret z; drop z;
      Call Xsay "Ergebnis/Prepare=" sqlca.sqlcode", "sqlca.sqlerrmc" ("!SQL_Stmt")";
   end;
   else;do
      call sqlexec "EXECUTE "Statmnt;
      if sqlca.sqlcode <> 0 then
         Call Xsay "Ergebnis/"What"=" sqlca.sqlcode", "sqlca.sqlerrmc;
   end;

return sqlca.sqlcode;

/*:VRX         Fini
*/
Fini:
    window = VRWindow()
    call VRSet window, "Visible", 0
    drop window
return 0

/*:VRX         Halt
*/
Halt:
    signal _VREHalt
return

/*:VRX         Init
*/
Init:
    window = VRWindow()
    call VRMethod window, "CenterWindow"
    call VRSet window, "Visible", 1
    call VRMethod window, "Activate"
    drop window



nok = RxFuncAdd("SysLoadFuncs",  "RexxUtil", "SysLoadFuncs") ;rc = SysLoadFuncs();

/* -----------------            */
/* DB2 registrieren:            */
/* -----------------            */
ok1 = RxFuncAdd("SQLDBS", "SQLAR", "SQLDBS");
ok2 = RxFuncAdd("SQLEXEC", "SQLAR", "SQLEXEC");
if (ok1+ok2) <> 0 & (ok1+ok2) <> 2 then do
   say "Fehler beim Init DB2, Code="ok1", "ok2".";
   Call Quit;
end;

nok = RxFuncAdd("FileLoadFuncs", "FILEREXX", "FileLoadFuncs");rc = FileLoadFuncs();
nok = RxFuncAdd("RxExtra",       "RxExtras", "RxExtra")      ;rc = RxExtra("LOAD");

nok = RxFuncAdd("CGT_GetLJCmnd", "CigTools", "CGT_GetLJCmnd");
nok = RxFuncAdd("MPS_MkTQuot",   "MPSTools", "MPS_MkTQuot");

if 0 then ok =  VRRedirectStdIO("OFF"); /* 1: makes console invisible   */

!FreeMem.Start = RxMemAvail() / ( 1024 * 1024 );    /* in MB            */
value  = RxQueryCountryInfo( "Countrydata." )
CountryCode = Countrydata.Country_Code;

/*  ------------------                  */
/*  Globale Variable:                   */
/*  ------------------                  */

ThisName = "DB2Edit";

YGlob.   = "";

YGlob.BorderWidth  = 8;     /* Rahmen ohne Scrollbar */
YGlob.BorderHeight = 30;    /* MenÅleiste            */

YGlob.StartupDir =  ,
      filespec("drive", RxGetExeName())||filespec("path", RxGetExeName());
                                                /* Problem: zeigt auf g:\_tmp1\ */
YGlob.StartupDir = directory();
YGlob.INIFile    = directory()"\"ThisName".ini";

/* Interne DB_Parameter:    */
YGlob.DBMS       = "DB2";

YGlob.Printer    = "LPT1";

/* --------------------                    */
/* Div. Dialog-Buttons:                    */
/* --------------------                    */
Buttons.0 = 3;
Buttons.1 = "OK";
Buttons.2 = "Cancel";
Buttons.3 = "Help";

Default   = 1;
Escape    = 2;
But_OK    = 1;
But_Esc   = 2;
But_Canc  = But_Esc;

ButtonsYN.0 = 2;
ButtonsYN.1 = "Yes";
ButtonsYN.2 = "No";

ButtonsYNC.0 = 3;
ButtonsYNC.1 = "Yes";
ButtonsYNC.2 = "No";
ButtonsYNC.3 = "Cancel";

/* --------------------------------------   */
/* Einen Database-Namen aus INI besorgen:   */
/* --------------------------------------   */
YGlob.DBName = ZSet_DBName("INI");

Call XSay "Connecting to DB2 with "YGlob.DBName"...";

ok = ZGet_DBNames();  /* FÅlle Combo-Box mit verfÅgbaren DBNames  */

/*  ------------------------         */
/*  CONNECT to DB2-Database:         */
/*  ------------------------         */
do until sqlca.sqlcode = 0 | ( sqlca.sqlcode<>-1032 & sqlca.sqlcode<>0 )
   Call ZDB2_Connect "FIRST";
   if sqlca.sqlcode = -1032 then do         /* -1032: DB/2 nicht aktiv         */
      Call Xsay "About to start Database Manager...";
      Call VRRedirectStdIO "OFF";           /* Ausschalten Redirection         */
      'startdbm';
      Call VRRedirectStdIO "ON";            /* wiedereinschalten Redirection   */

      if RC=0 then  Call Xsay "DB/2 gestartet";
      else;         Call Xsay "Ergebnis/Startdbm="RC;
   end;
   else;do
      if sqlca.sqlcode <> 0 then
         Call XSay "Invalid databasename; you must select one from the list on the top left";
   end;
end;

return;
/* ---------------- return from INIT ----------------   */

/* ---------------- interne Functions: ---------------------    */

/* --------------------------------------------------      */
/* AuffÅllen links Zahl mit fÅhrenden Nullen:              */
/* --------------------------------------------------      */
PadZero: procedure
    What = arg(1);
    Leng = arg(2);
    return left("0", Leng-length(What), "0")||What;

/* -------------------------------------------      */
/* Mach 2 Quotes dort, wo sich eines befindet:      */
/* -------------------------------------------      */
MakeTwoQuotes: procedure
What = arg(1);
Char = arg(2);
if What = "" then return "";
if Char = "" then
   return MPS_MkTQuot( What );
else;
   return MPS_MkTQuot( What, Char );

/* -------------------------------------------      */
/* Xsay / Ysay:                                     */
/* -------------------------------------------      */
XSay: procedure
What = arg(1);
if strip(What) = "" | What="TOF" | What="BOF" then return;
ok = VRMethod("LB_XSay", "Addstring", What);
ok = VRSet("LB_XSay", "Selected", VRGet("LB_XSay", "Count"));
return;
/*:VRX         LB_Columns_ContextMenu
*/
LB_Columns_ContextMenu: 

ok = VRMethod("MM_ColumnList", "PopUp");

return;

/*:VRX         LB_Columns_DoubleClick
*/
LB_Columns_DoubleClick: 

ok = VRMessage( VRWindow(), "Use the Context Menu for functions", "Just a hint" );

if(1) then RETURN 0;    /* das folgende ist irgendwie falsch!   */


/* Listentry besorgen (= Columns-Entry):       */

Indx = VRInfo("Index")

TableEntry = VRMethod("LB_Tables", "GetString", Indx );

/*  !TabName  steht noch        */

!ColName  = word(TableEntry,1);
!ColCount = word(TableEntry,2);

Call VRSet "CN_Columns", "Visible", 0;

SelectStatement = ,
  "select ColName, ColNo, Scale, Length, TypeName from syscat.columns"  ,
  " where tabname = '"translate(!TabName)"'"                            ,
  " order by ColNo";


s1 = space(SelectStatement);
Call Xsay "SelectStatement="SelectStatement;
call sqlexec "PREPARE s1 FROM :s1";     if sqlca.sqlcode<>0 then Call XSay "Error Prepare, sqlcode="sqlca.sqlcode;
call sqlexec "DECLARE c1 CURSOR FOR s1";if sqlca.sqlcode<>0 then Call XSay "Error Declare, sqlcode="sqlca.sqlcode;
call sqlexec "OPEN  c1";                if sqlca.sqlcode<>0 then Call XSay "Error Open, sqlcode="sqlca.sqlcode;

MaxRecs  = 99999;
i=0;
do until ( sqlca.sqlcode <> 0 | TotCount > MaxRecs )
   call sqlexec "FETCH c1 INTO",
            ":ColName   :IDummy,  ",
            ":ColNo     :IDummy,  ",
            ":Scale     :IDummy,  ",
            ":Length    :IDummy,  ",
            ":TypeName  :IDummy   ";

   if sqlca.sqlcode = 0 then do
      i = i +1;

      /* ------------------------------                    */
      /* Felder fÅr Records definieren:                    */
      /* ------------------------------                    */
      if TypeName = "DECIMAL" then ColType = "ULONG";
      else;                        ColType = "STRING"
      hndTble.i = VRMethod("CN_Columns", "AddField", ColType, ColName );

   end;
   else;do
     if sqlca.sqlcode <> 100 then
        Call Xsay sqlca.sqlcode" ("sqlca.sqlerrmc")";
   end;
end;
Call Xsay "nach Fetch: Sqlcode="sqlca.sqlcode", "sqlca.sqlerrmc;
call sqlexec "CLOSE c1";

Call VRSet "CN_Columns", "Visible", 1;

return;

/*:VRX         LB_Tables_ContextMenu
*/
LB_Tables_ContextMenu: 

    ok = VRMethod("MM_ActionTable", "PopUp");

return;

/*:VRX         LB_Tables_DoubleClick
*/
LB_Tables_DoubleClick: 

/* zuerst die alte Container-Instanz lîschen um dann neu anzulegen
   (weil es gibt kein Delete-Field):
   ---------------------------------------------------------------  */
ok = ZCreate_Container();


/* nun Listentry besorgen (= Tabellen-Entry):       */

Indx = VRInfo("Index")

TableEntry = VRMethod("LB_Tables", "GetString", Indx );

!TabName  = word(TableEntry,1);
!Definer  = word(TableEntry,2);
!ColCount = word(TableEntry,3);

ok = VRSet("EF_CurTable", "Value", !TabName);

Call VRSet "CN_Columns", "Visible", 0;

SelectStatement = ,
  "select DISTINCT ColName, ColNo, Scale, Length, TypeName from syscat.columns"  ,
  " where tabname = '"translate(!TabName)"'"                            ,
  " order by ColNo";

s1 = space(SelectStatement);
Call Xsay "SelectStatement="SelectStatement;
call sqlexec "PREPARE s1 FROM :s1";     if sqlca.sqlcode<>0 then do;Call XSay "Error Prepare, sqlcode="sqlca.sqlcode;return;end;
call sqlexec "DECLARE c1 CURSOR FOR s1";if sqlca.sqlcode<>0 then do;Call XSay "Error Declare, sqlcode="sqlca.sqlcode;return;end;
call sqlexec "OPEN  c1";                if sqlca.sqlcode<>0 then do;Call XSay "Error Open, sqlcode="sqlca.sqlcode;   return;end;

MaxRecs  = 99999;
i=0;
ListData. = "";
ok = VRMethod("LB_Columns", "Clear");
do until ( sqlca.sqlcode <> 0 | TotCount > MaxRecs )
   call sqlexec "FETCH c1 INTO",
            ":ColName   :IDummy,  ",
            ":ColNo     :IDummy,  ",
            ":Scale     :IDummy,  ",
            ":Length    :IDummy,  ",
            ":TypeName  :IDummy   ";

   if sqlca.sqlcode = 0 then do
      i = i +1;

      /* ------------------------------                    */
      /* Felder fÅr Records definieren:                    */
      /* ------------------------------                    */

      ListData.i = PadZero(ColNo,2) ColName TypeName;

   end;
   else;do
     if sqlca.sqlcode <> 100 then
        Call Xsay sqlca.sqlcode" ("sqlca.sqlerrmc")";
   end;
end;
ListData.0 = i;
Call Xsay "nach Fetch: Sqlcode="sqlca.sqlcode", "sqlca.sqlerrmc;
call sqlexec "CLOSE c1";

ok = VRMethod("LB_Columns", "AddStringList", "ListData.");

drop ListData.

/* --------------------------------------------------------------   */
/* Nun COUNT(*) besorgen, dazu muss Table-Owner ermittelt werden:   */
/* --------------------------------------------------------------   */
OwnerID = ZGet_OwnerID(!Definer,!TabName);

ok = VRSet("EF_TotRecds", "Value", ZSelect_Count(OwnerID"."!TabName) );

return;

/*:VRX         LB_XSay_ContextMenu
*/
LB_XSay_ContextMenu: 

    ok = VRMethod("MM_XSay", "Popup");

return;

/*:VRX         LB_XSay_DoubleClick
*/
LB_XSay_DoubleClick: Procedure;

Buttons.1 = "OK";
Buttons.2 = "Help";
Buttons.0 =  2;

ok = VRMethod("LB_XSay", "GetSelectedList", "indexes.");

ok = VRMessage( VRWindow(), VRMethod("LB_XSay", "GetString", indexes.1),    ,
                "Message in the Log Window", "I", "Buttons.", 2, 1          ,
              );


if ok = 2 then do
   ok = VRMethod( "LB_XSay", "InvokeHelp" );
end;

return

/*:VRX         MM_ActionTable_Click
*/
MM_ActionTable_Click: 

Index = VRInfo("Index");

!TableName = word( VRMethod("LB_Tables", "GetString", Index), 1);

return

/*:VRX         MM_Col_ResetOrder_Click
*/
MM_Col_ResetOrder_Click: 

ok = VRSet("EF_OrderBy", "Value", "");

return;

/*:VRX         MM_Col_UseOrder_Click
*/
MM_Col_UseOrder_Click: Procedure

Indx = VRInfo("Index");

ColName = word( VRMethod("LB_Columns", "GetString", Indx), 2);

OldVal = VRGet("EF_OrderBy", "Value", ColName);
If OldVal = "" then 
   Komma = "";
else;
   Komma = ", ";

ok = VRSet("EF_OrderBy", "Value", OldVal||Komma||ColName);

return;

/*:VRX         MM_ExportTable_Click
*/
MM_ExportTable_Click: 

    Call VRLoadSecondary "WIN_Export";

return;

/*:VRX         MM_Help_About_Click
*/
MM_Help_About_Click: 

    ok = VRLoadSecondary( "WIN_About" );


return

/*:VRX         MM_Help_HowTo_Click
*/
MM_Help_HowTo_Click: 

if CountryCode = 49 | CountryCode = 41 then 
   ok = VRSet("MM_Help_HowTo", "HelpText", "(HowTo_De.hlp)");
else;
   ok = VRSet("MM_Help_HowTo", "HelpText", "(HowTo_En.hlp)");

ok = VRMethod("MM_Help_HowTo", "InvokeHelp");

return

/*:VRX         MM_SetDBName_Click
*/
MM_SetDBName_Click: 

    YGlob.DBName = ZSet_DBName("USER");

return;

/*:VRX         MM_Upd_DoTheUpdate_Click
*/
MM_Upd_DoTheUpdate_Click: 

    Call PB_Upd_CurRow_Click;

return;

/*:VRX         MM_XSay_SaveLog_Click
*/
MM_XSay_SaveLog_Click: 

LogstatusFile = "DB2Edit.log";

but = VRPrompt( VRWindow, "Enter a file name for saving the Log Status Window",,
                "LogstatusFile", "Please do it...",     ,
                "Buttons."  ,
              );
if but = 2 then RETURN;

Heute = date("S");
Call XSay "Saving Log-Status to File="LogstatusFile" on "left(Heute,4)"-"substr(Heute,5,2)"-"right(Heute,2)" time="time();

ok = SysFileDelete(LogstatusFile);
do i = 1 to VRGet("LB_Xsay", "Count");
   ok = lineout( LogstatusFile, VRMethod("LB_XSay", "GetString", i) );
end;
ok = stream(LogstatusFile, "c", "close");

drop LogstatusFile;

return;


/*:VRX         MMExit_Click
*/
MMExit_Click: 

    Call PB_Exit_Click;

return;

/*:VRX         PB_About_Close_Click
*/
PB_About_Close_Click: 

    Call WIN_About_Close;

return

/*:VRX         PB_Exit_Click
*/
PB_Exit_Click: 

    Call Quit;

return

/*:VRX         PB_Expo_Select_Click
*/
PB_Expo_Select_Click: 


/* Namens-Stamm vorschlagen:                                */
if VRGet("RB_Expo_IXF", "Set") then DefName = "*.IXF";
if VRGet("RB_Expo_DEL", "Set") then DefName = "*.DEL";

ExpFileSpec = VRGet("EF_Expo_Target", "Value" );

DefName = filespec("drive",ExpFileSpec) || filespec("path",ExpFileSpec) || DefName;

say "DefName="DefName"!";

ExpFileSpec = VRFileDialog( VRWindow()  ,
                          , "Select Export-file", "Save", DefName, , ,    ,
                          )

if ExpFileSpec = "" then RETURN;

ok = VRSet("EF_Expo_Target", "Value", ExpFileSpec );

return;

/*:VRX         PB_ExpoClose_Click
*/
PB_ExpoClose_Click: 

    Call WIN_Export_Close;

return;

/*:VRX         PB_ExpoDoIt_Click
*/
PB_ExpoDoIt_Click: 

TableName   = VRGet("EF_Expo_TableName", "Value" );
ExpFileSpec = VRGet("EF_Expo_Target",    "Value" );

ok = SysINI( INFile, "Settings", "ExpFileSpec", ExpFileSpec );

/* ---------------------------------------------------          */
/* Datei zuvor lîschen:                                         */
/* ---------------------------------------------------          */
ok = SysFileDelete(ExpFileSpec);

/* ---------------------------------------------------          */
/* Optional: Header-Record vorweg schreiben:                    */
/* ---------------------------------------------------          */
HdrRec = VRGet("EF_Expo_HdrRec","Value");
if HdrRec <> "" then do
   ok = LineOut(ExpFileSpec,HdrRec);
   ok = stream(ExpFileSpec,"c","close");
   ok = SysINI( YGlob.INIFile, "Settings", "HdrRec", HdrRec )
end;


if VRGet("CB_Expo_Manuell","Set") then do
   Call ZExport_Manuell;
   RETURN 0;
end;

OrderClause = VRGet("EF_Expo_Order", "Value");
if OrderClause <> "" then
   OrderClause = "Order by "OrderClause;

if VRGet("RB_Expo_IXF", "Set") then Commandstring = "export to "ExpFileSpec" of ixf";
if VRGet("RB_Expo_DEL", "Set") then Commandstring = "export to "ExpFileSpec" of del";

Commandstring = Commandstring "select * from "TableName OrderClause;


Call XSay "Executing '"Commandstring"'";

if(0) then Call dbm Commandstring;      /* NOK: 'Es besteht keine Verbindung zur Datenbank'     */
else;
           Call sqldbs Commandstring;   /* klappt irgendwie auch nicht: '-104 to EXPORT <HOST> ...' */

say sqlca.sqlcode", "sqlca.sqlerrmc;

/* ... deshalb manuell per Kommandozeile:       */

ok = VRMethod( "Application", "PutClipboard", Commandstring );

Call XSay "Commandstring put to clipboard"; ok = beep(222,333);

return;

/*:VRX         PB_FontLarger_Click
*/
PB_FontLarger_Click: 

ok = ZSet_FontSize("+");

return;

/*:VRX         PB_FontSmaller_Click
*/
PB_FontSmaller_Click: 

ok = ZSet_FontSize("-");

return;

/*:VRX         PB_RollBack_Click
*/
PB_RollBack_Click: 

sql1 = "ROLLBACK";

ok = DoTheSql("sql1","Rollback");

if ok = 0 then
   Call XSay "Rollback successfully processed.";
else;
   Call XSay "Error with Rollback, sqlcode="ok;


return;
/*:VRX         PB_ShowTableData_Click
*/
PB_ShowTableData_Click: 

ok = ZUpd_Reset();

ok = VRSet("PB_Upd_CurRow", "Enabled", 0 );     /* jetzt ist noch kein Row-Update mîglich   */

ok = ZCreate_Container();

/* -----------------------------------------------  */
/* Schauen, ob einzelne Columns selektiert wurden:  */
/* -----------------------------------------------  */

ok = VRMethod("LB_Columns","GetSelectedList", "Sels.");
if Sels.0 = 0 then do
   /* also alle Columns selektieren:    */
   do i = 1 to VRGet("LB_Columns","Count")
      Sels.i = i;
   end;
   Sels.0 = i-1;
   ok = VRMethod("LB_Columns","SetSelectedList", "Sels.");
end;
do i = 1 to Sels.0
   ColData = VRMethod("LB_Columns","GetString", Sels.i);
   
   ColNo    = word(ColData,1);
   ColName  = word(ColData,2);
   TypeName = word(ColData,3);

   if TypeName = "DECIMAL" then ColType = "ULONG";
   else;                        ColType = "STRING"

   /* FÅllen Tabelle der Field-Handles:                 */
   hndTble.i = VRMethod("CN_Columns", "AddField", ColType, ColName, "" );
   FrmTble.i = TypeName;
   FlgTble.i = "";
end;
hndTble.0  = i-1;
FrmTble.0  = i-1;     /* Zu jedem Field-Handle gibt es ein Format = DB2-Column-Type                       */
FlgTble.0  = i-1;     /* Zu jedem Field-Handle gibt es ein Flag ('U' => Update-Request for this Column)   */

/* -----------------------------------------------  */

ok = VRMethod("LB_Columns", "GetSelectedList", "Sels.");
SelCols.  = "";
SelCols.0 = 0;
do i = 1 to Sels.0
   /* Sammle selektierte Column-Namen in Stem (aus Listbox):    */
   SelCols.i = word( VRMethod("LB_Columns", "GetString", Sels.i ), 2); /* das 2. Wort der Columns-Listbox-EintrÑge ist der Column-Name  */
end;
SelCols.0 = Sels.0;


/* ----------------     */
/* Nun Daten lesen:     */
/* ----------------     */

Sql1 = "Select "
do i = 1 to hndTble.0
    ColName = VRMethod("CN_Columns", "GetFieldAttr", hndTble.i, "Title");

    /* schau, ob der ColName sich in der Liste der gewÅnschten Columns befindet: */
    if SelCols.0 > 0 then do
       YSelCol = 0;
       do j = 1 to SelCols.0
          if ColName = SelCols.j then
             YSelCol = 1;
       end;
    end;
    else;YSelCol = 1;
    if (YSelCol) then 
       Sql1 = Sql1 || ColName ",";

end;
Sql1 = left(Sql1, length(Sql1)-1);  /* strip letztes Komma  */

OwnerID = ZGet_OwnerID(!Definer,!TabName);

Sql1 = Sql1||" from "OwnerID"."!TabName;

/* ---------------------------------    */
/* HinzufÅgen WHERE-Klausel, if any:    */
/* ---------------------------------    */
WhereKlaus = VRGet("EF_Where", "Value");
If WhereKlaus <> "" then 
   Sql1 = Sql1 " Where "WhereKlaus;

/* -----------------------------------  */
/* HinzufÅgen ORDERBY-Klausel, if any:  */
/* -----------------------------------  */
OrderKlaus = VRGet("EF_OrderBy", "Value");
If OrderKlaus <> "" then 
   Sql1 = Sql1 " Order By "OrderKlaus;

s1 = space(Sql1);
Call Xsay "SelectStatement="Sql1;
call sqlexec "PREPARE s1 FROM :s1";     if sqlca.sqlcode<>0 then Call XSay "Error Prepare, sqlcode="sqlca.sqlcode;
call sqlexec "DECLARE c1 CURSOR FOR s1";if sqlca.sqlcode<>0 then Call XSay "Error Declare, sqlcode="sqlca.sqlcode;
call sqlexec "OPEN  c1";                if sqlca.sqlcode<>0 then Call XSay "Error Open, sqlcode="sqlca.sqlcode;

FetchCmd = "FETCH c1 INTO ";
do i = 1 to hndTble.0
    !ColName = VRMethod("CN_Columns", "GetFieldAttr", hndTble.i, "Title");
    FetchCmd = FetchCmd ":"!ColName" :I"!ColName||",";
end;
FetchCmd = left(FetchCmd, length(FetchCmd)-1);  /* strip letztes Komma  */


/* -----------------------------------------------  */
/* Nun geht's los:                                  */
/* -----------------------------------------------  */
MaxRows = VRGet("EF_MaxRows", "Value");
If MaxRows = 0 then MaxRows = 999999999;
RowNo=0;
CN_Data. = "";
do until ( sqlca.sqlcode <> 0 ) | ( RowNo >= MaxRows )
   call sqlexec FetchCmd;

   if sqlca.sqlcode = 0 then do

      if RowNo = MaxRows then LEAVE;

      RowNo = RowNo +1;
      ok = VRSet("EF_RowNo", "Value", RowNo );

Delim = "FE"x;  /* anstatt ';'                             */

      /* -------------------------------------------       */
      /* gelesene Column-Values in Record einfÅllen:       */
      /* -------------------------------------------       */
      CurCN_Data = left(Delim,5,Delim);
      do i = 1 to hndTble.0
         !ColName = VRMethod("CN_Columns", "GetFieldAttr", hndTble.i, "Title");
         z = "!IndVar =I"!ColName; interpret z;
         if !IndVar < 0 then
            !ColData = "NULL";
         else;do
            z = "!ColData = Strip("!ColName")";   interpret z;  
         end;
         CurCN_Data = CurCN_Data || hndTble.i ||Delim|| !ColData ||Delim;
      end;
      CN_Data.RowNo = left(CurCN_Data, length(CurCN_Data)-1);
   end;
   else;do
     if sqlca.sqlcode <> 100 then
        Call Xsay sqlca.sqlcode" ("sqlca.sqlerrmc")";
   end;
end;

CN_Data.0 = RowNo;
Call Xsay "nach Fetch: Sqlcode="sqlca.sqlcode", "sqlca.sqlerrmc;
call sqlexec "CLOSE c1";

Call VRMethod "CN_Columns", "AddrecordList", , "Last", "CN_Data.";

Call VRSet "CN_Columns", "Visible", 1;

return;

/*:VRX         PB_ShowTables_Click
*/
PB_ShowTables_Click: 

WhatList = "LB_Tables";

Call VRMethod WhatList, "Clear";

SelectStatement = ,
  "select TabName, Definer, ColCount from syscat.tables";

if \VRGet("CB_Incl_SysTables", "Set") then
    SelectStatement = SelectStatement "where not Definer like 'SYS%'";

SelectStatement = SelectStatement "Order by TabName";

s1 = space(SelectStatement);
Call Xsay "SelectStatement="SelectStatement;
call sqlexec "PREPARE s1 FROM :s1";     if sqlca.sqlcode<>0 then do;Call XSay "Error Prepare, sqlcode="sqlca.sqlcode","sqlca.sqlerrmc;return;end;
call sqlexec "DECLARE c1 CURSOR FOR s1";if sqlca.sqlcode<>0 then do;Call XSay "Error Declare, sqlcode="sqlca.sqlcode","sqlca.sqlerrmc;return;end;
call sqlexec "OPEN  c1";                if sqlca.sqlcode<>0 then do;Call XSay "Error Open, sqlcode="sqlca.sqlcode","sqlca.sqlerrmc;   return;end;

TotCount = 0;i=0;
LstData.  = "";
LstData.0 = 0;
do until ( sqlca.sqlcode <> 0 | TotCount > MaxRecs )
   call sqlexec "FETCH c1 INTO",
            ":TabName   :IDummy,  ",
            ":Definer   :IDummy,  ",
            ":ColCount  :IDummy";

   if sqlca.sqlcode = 0 then do
      TotCount = TotCount +1;

      LstEntry = left(TabName,20) left(Definer,12) ColCount;
      i = LstData.0; i=i+1;
      LstData.i = LstEntry;
      LstData.0 = i;
   end;
   else;do
     if sqlca.sqlcode <> 100 then
        Call Xsay sqlca.sqlcode" ("sqlca.sqlerrmc")";
   end;
end;
Call Xsay "nach Fetch: Sqlcode="sqlca.sqlcode", "sqlca.sqlerrmc;
call sqlexec "CLOSE c1";

drop TabName Definer ColCount;

Call VRMethod WhatList, "AddStringList", "LstData.";

return sqlca.sqlcode;

/*:VRX         PB_Upd_CurRow_Click
*/
PB_Upd_CurRow_Click: 

/* 
   Zusammenbasteln eines UPDATE-Statements:

   Gesetzt sind:
   > Die WHERE-Klause in hndTble.UpdWhere
   > die Update-relevanten Columns sind in FlgTble.n mit 'U' markiert
   > der Handle des zuletzt in EndEdit bearbeiteten Records: 'hndRec'
   > der aktuelle Tabellen-Name: '!TabName'

   */

sql1 = "UPDATE "!TabName" SET ";

/* Aufsuchen alle update-relevanten Field-Handles:   */

do i = 1 to hndTble.0
   if FlgTble.i = "U" then do
      !ColName = VRMethod("CN_Columns", "GetFieldAttr", hndTble.i, "Title" );
      !ColData = VRMethod("CN_Columns", "GetFieldData", hndRec, hndTble.i );

      if \( FrmTble.i = "DECIMAL" | FrmTble.i = "INTEGER" | FrmTble.i = "SMALLINT" ) then
         !ColData = "'"||MakeTwoQuotes(!ColData)||"'";

      sql1 = sql1 !ColName "=" !ColData ",";
   end;
end;

sql1 = left(sql1, length(sql1)-1);
sql1 = sql1 hndTble.UpdWhere;

But = VRPrompt( VRWindow(), "SQL-Statement to be executed (you can edit before you press OK)",  "sql1", ,
                            "Update current row in table "!Table, "ButtonsYNC."  ,
              );

if But = 1 then do
   say "doing the update! Actual sql="sql1;
end;
if But = 2 then do
   say "No update requested!";
   YEdit.KeyCols.0  = 0
   RETURN -1;
end;
if But = 3 then do
   say "Cancel requested";
   RETURN -1;
end;

/* DO THE UPDATE!       */

ok = DoTheSql("sql1","Update Current Row");

if ok = 0 then
   Call XSay "Update of current row successfully processed.";
else;
   Call XSay "Error updating current row, sqlcode="ok;

/* nach dem Update:     */
ok = ZUpd_Reset();

return;
/*:VRX         Quit
*/
Quit:

ok = VRRedirectStdIO("OFF"); /* Makes console invisible  */

    window = VRWindow()
    call VRSet window, "Shutdown", 1
    drop window
return

/*:VRX         WIN_About_Close
*/
WIN_About_Close: 
    call WIN_About_Fini
return

/*:VRX         WIN_About_Create
*/
WIN_About_Create: 
    call WIN_About_Init;

ok = VRSet("WIN_About", "Painting", 0);

/* Zuerst zwei Felder definieren:           */

hndWhat  = VRMethod("CN_About", "AddField", "String" );
hndValue = VRMethod("CN_About", "AddField", "String" );

ok = ZAdd_About("",,"",,);              /* Leerzeile fÅr die markierte Zeile    */
ok = ZAdd_About("Version:",,"1.01",,);
ok = ZAdd_About("Author:",,"Lutz Wagner",,);
ok = ZAdd_About("Kontakt:","Contact","Lutz@Wagner-Systemberatung.de",,);

ok = VRSet("WIN_About", "Painting", 1);

return;

-----------------------------------------------------


ZAdd_About: Procedure Expose    ,
                      CountryCode hndWhat hndValue

What_DE  = arg(1);
What_EN  = arg(2);
Value_DE = arg(3);
Value_EN = arg(4);

if What_EN  = "" then What_EN  = What_DE;
if Value_EN = "" then Value_EN = Value_DE;

if CountryCode = 49 | CountryCode = 41 | CountryCode = 43 then do
   What  = What_DE;
   Value = Value_DE;
end;
else;do;
   What  = What_EN;
   Value = Value_EN;
end;

hndRec   = VRMethod("CN_About", "Addrecord" );
ok =  VRMethod("CN_About", "SetFieldData", hndRec, hndWhat,  What );
ok =  VRMethod("CN_About", "SetFieldData", hndRec, hndValue, Value );

return 0;

/*:VRX         WIN_About_Fini
*/
WIN_About_Fini: 
    window = VRInfo( "Window" )
    call VRDestroy window
    drop window
return
/*:VRX         WIN_About_Init
*/
WIN_About_Init: 
    window = VRInfo( "Object" )
    if( \VRIsChildOf( window, "Notebook" ) ) then do
        call VRMethod window, "CenterWindow"
        call VRSet window, "Visible", 1
        call VRMethod window, "Activate"
    end
    drop window
return

/*:VRX         WIN_Export_Close
*/
WIN_Export_Close: 
    call WIN_Export_Fini
return

/*:VRX         WIN_Export_Create
*/
WIN_Export_Create: 

ok = VRMethod("CN_Columns","GetRecordList", "ALL", "Recs." );
if Recs.0 = 0 then do
   ok = VRMessage( VRWindow(), "No table-data in container", "Click 'Show Table-Data' first" );
   RETURN -1;
end;
    call WIN_Export_Init;

ok = VRSet("EF_Expo_TableName", "Value", !TableName);

ExpFileSpec = SysINI( YGlob.INIFile, "Settings", "ExpFileSpec" );
if ExpFileSpec = "ERROR:" then ExpFileSpec = "";
ok = VRSet("EF_Expo_Target", "Value", ExpFileSpec);

HdrRec = SysINI( YGlob.INIFile, "Settings", "HdrRec", HdrRec )
if HdrRec = "ERROR:" then HdrRec = "";
ok = VRSet("EF_Expo_HdrRec","Value",HdrRec);

return;

/*:VRX         WIN_Export_Fini
*/
WIN_Export_Fini: 
    window = VRInfo( "Window" )
    call VRDestroy window
    drop window
return
/*:VRX         WIN_Export_Init
*/
WIN_Export_Init: 
    window = VRInfo( "Object" )
    if( \VRIsChildOf( window, "Notebook" ) ) then do
        call VRMethod window, "CenterWindow"
        call VRSet window, "Visible", 1
        call VRMethod window, "Activate"
    end
    drop window
return

/*:VRX         Window1_Close
*/
Window1_Close:
    call Quit
return

/*:VRX         ZCreate_Container
*/
ZCreate_Container: 

ok = VRDestroy("CN_Columns");
ok = VRCreate( GB_Columns   ,
            , "Container"   ,
            , "Width", 10996, "Height", 3600, "Top", 60, "Left", 20   ,
            , "Name","CN_Columns"  ,
            , "View","Detail"       ,
            , "Caption", "Columns of Table:"    ,
            , "CaptionSeparator", "1"           ,
            , "Visible", "1"                    ,
             );

ok = VRSet("CN_Columns", "Font", "10.System VIO");
ok = VRSet("CN_Columns", "BeginEdit", "Call CN_Columns_BeginEdit");
ok = VRSet("CN_Columns", "EndEdit",   "Call CN_Columns_EndEdit");

ok = VRSet("CN_Columns", "ShowCaption",      1);
ok = VRSet("CN_Columns", "CaptionSeparator", 1);
ok = VRSet("CN_Columns", "Caption", "Values of Table:");

return 0;

/*:VRX         ZDB2_Connect
*/
ZDB2_Connect: 

if arg(1) <> "FIRST" then do
   sql1 = "COMMIT";
   ok = DoTheSQL("sql1","release connection");
end;

   call sqldbs "start using database "YGlob.DBName" in Share mode";
   Call Xsay "Ergebnis/Connect to "YGlob.DBName"=" sqlca.sqlcode;

if sqlca.sqlcode = -1032 then
   Call Xsay "Database manager not active!";

return;

/*:VRX         ZExport_Manuell
*/
ZExport_Manuell: 

Delim = "FE"x;  /* anstatt ';'          */

OutFile = ExpFileSpec;

ok = VRMethod("CN_Columns","GetRecordList", "ALL", "Recs." );

do i = 1 to Recs.0
   Rec = Recs.i;

   ok = VRMethod("CN_Columns","SetRecordAttr", Rec, "Selected", 1 );

   xSV_Rec = "";
   do j = 1 to hndTble.0
      Data = VRMethod("CN_Columns", "GetFieldData", Rec, hndTble.j );
      xSV_Rec = xSV_Rec || Delim || Data;
   end;
   xSV_Rec = strip(xSV_Rec,"L",Delim);    /* letzten Delim wieder weg */
   ok = LineOut( OutFile, xSV_Rec );
end;
ok = stream( OutFile, "c","close" );

if(0) then ok = CharOut( OutFile, "1A"x );     /* braucht die fgets()-Funktion (?)     */

Call XSay i-1 "Records from" VRGet("EF_CurTable","Value") "as shown in container have been exported to "OutFile; ok = beep(222,333);


return

/*:VRX         ZGet_DBNames
*/
ZGet_DBNames: Procedure

"dbm list db directory > $temp.dat";

InFile = "$Temp.dat";

i=1;
KeyWord.i = translate("Aliasname der Datenbank");  i = i+1;
KeyWord.i = translate("Alias of Database");        i = i+1;
KeyWord.0 = i-1;

ok = VRMethod("Combo_DBNames", "Clear");

do i = 1 to KeyWord.0

   do while lines(InFile) > 0
      Rec = linein(InFile);
      if translate( left( strip(Rec), length(KeyWord.i)) ) = KeyWord.i then do
         DBName = word(Rec, words(Rec));
         ok = VRMethod("Combo_DBNames", "AddString", DBName);
      end;
   end;
   ok = stream(InFile,"c","close");

   if VRGet("Combo_DBNames", "Count") > 0 then
      LEAVE;

end;

return 0;

/*:VRX         ZGet_OwnerID
*/
ZGet_OwnerID: procedure

!Definer = arg(1);
!TabName = arg(2);

if left(!Definer,3) = "SYS" then do
   if left(!TabName,3) = "SYS" then
      OwnerID = "SYSIBM"; 
   else;
      OwnerID = "SYSCAT";
end;
else;do;
   OwnerID=!Definer;
end;

return OwnerID;


/*:VRX         ZSelect_Count
*/
ZSelect_Count: Procedure Expose sqlca.

s1 = "select COUNT(*) from "arg(1);

call sqlexec "PREPARE s1 FROM :s1";     if sqlca.sqlcode<>0 then do;Call XSay "Error Prepare, sqlcode="sqlca.sqlcode;return sqlca.sqlcode;end;
call sqlexec "DECLARE c1 CURSOR FOR s1";if sqlca.sqlcode<>0 then do;Call XSay "Error Declare, sqlcode="sqlca.sqlcode;return sqlca.sqlcode;end;
call sqlexec "OPEN  c1";                if sqlca.sqlcode<>0 then do;Call XSay "Error Open, sqlcode="sqlca.sqlcode;   return sqlca.sqlcode;end;

   call sqlexec "FETCH c1 INTO :Count :ICount";

   if sqlca.sqlcode = 0 then do
      if ICount < 0 then Count = 0;

   end;
   else;do
      Call Xsay sqlca.sqlcode" ("sqlca.sqlerrmc")";
   end;

call sqlexec "CLOSE c1";

return Count;
/*:VRX         ZSet_DBName
*/
ZSet_DBName: procedure Expose   ,
                        YGlob.  ,
                        Buttons.

What = translate(arg(1));

/*         INI              */
If What = "INI" then do     /* get from INI-File    */
   ok=0
   do while (ok<>1 & ok<>2)
      !DBName = SysINI(YGlob.INIFile,"Settings","DBName");
      if !DBName = "ERROR:" then do
         !DBName = "<databasename>";
         ok = VRPrompt( VRWindow(), "Enter current Database-name", "!DBName", "Initial setting", ,
                        "Buttons.", 1, 2  ,
                      );
 
         if ok = 3 then do
            Call VRMethod "Window1", "InvokeHelp";
            ok=1;
         end;
      end;
      else;do
         ok = VRSet("Combo_DBNames", "Value", !DBName);
         ok = 1;
      end;
   end;
   if ok = 1 then do
      ok = SysINI(YGlob.INIFile,"Settings","DBName",!DBName);
   end;
end;

/*         USER             */
If What = "USER" then do    /* get from User    */

   !DBName = "<databasename>";
   But = VRPrompt( VRWindow(), "Enter current Database-name", "!DBName", "Current Database: "YGlob.DBName, ,
                   "Buttons.", 1, 2  ,
                 );
   if But = 1 then
      ok = SysINI(YGlob.INIFile,"Settings","DBName",!DBName);
end;

/*         FROMCOMBO        */
If What = "FROMCOMBO" then do    /* get from User    */

   Aux = VRGet("Combo_DBNames", "SelectedString");
   if left(Aux,1) = "<" | Aux = "" then do
      !DBName = SysINI(YGlob.INIFile,"Settings","DBName");
   end;
   else;
      !DBName = Aux;
end;

ok = VRSet("EF_CurDBName", "Value", !DBName);
ok = VRMethod("LB_Tables", "Clear");

YGlob.DBName = !DBName;
if What <> "INI" then
   Call ZDB2_Connect;

return !DBName;

/*:VRX         ZSet_FontSize
*/
ZSet_FontSize: Procedure
What = arg(1);  /* '-'  oder '+'    */

FontName = VRGet("CN_Columns", "Font" );

parse value FontName with FontSize "." FontFamily;

if Datatype(FontSize) <> "NUM" then do
   Call XSay "unable to alter font "FontName;
   RETURN -1;
end;

z = "FontSize = FontSize "What"1";  interpret z;

ok = VRSet("CN_Columns", "Font", FontSize||"."||FontFamily );

return 0;

/*:VRX         ZUpd_Reset
*/
ZUpd_Reset: 

ok = VRSet("PB_Upd_CurRow", "Enabled", 0 );     /* Init: kein Row-Update mîglich            */

YEdit.KeyCols.0  = 0    /* Primary Key-Columns einer sich im Update befindenden Table       */

hndTble.OldData  = "";  /* nicht feldbezogen    */
hndTble.NewData  = "";  /* nicht feldbezogen    */
hndTble.UpdWhere = "";  /* ÅberflÅssig, weil durch YEdit.KeyCols.0  = 0 ohnehin neugesetzt  */
FlgTble.         = "";
FrmTble.         = "";

return 0;

