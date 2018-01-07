(*Copyright (C) 2013, Remy Baccino, Hexadecimal Technologies.
  Contact : rbaccino@hexnode.net.

this file is part of an upcoming open-source datamining project called TGVMiner. 
Its use here is to demonstrate various uses of the Lua 5.2.1 library : 
	the TTGVPluginSetup class loads a specific Lua script on disk ("pluginName" string of TTGVPluginSetup),
	loads specific Pascal functions into it and executes it. It specifically allows the whole mining system to
	pass 2D data arrays to Lua scripts for dynamic filtering, and get them back properly filtered.
*)
unit tgvplugin;

{$mode objfpc}{$H+} {$M+}

interface

uses
  Classes, SysUtils, Lua;

type
    EMatchType =
    (
        PARTIAL_MATCH,
        PERFECT_MATCH,
        INCLUSION_MATCH
    ); 

    TTGVNormalizedData =
    record
          index    : cardinal;
          colCount : cardinal;
          rowCount : cardinal;
          title    : string;
          colNames : array of widestring;
          cells    : array of array of string;
    end;

    TTGVPluginSetup =
    record
          pluginName : string;
          pluginKeys : array of string;
          pluginValues : array of string;
    end;

    TTGVFilterPlugin =
    class
         private
               _pluginName : string;
               _inputData  : TTGVNormalizedData;
               _outputData : TTGVNormalizedData;
               _ps         : TTGVPluginSetup;
               _errorStr   : string;
               _lua        : TLua;

               function ReturnColIndex(const colName : string) : cardinal;
               function GetPluginName : PChar;
         published
    	       //this function allows the Lua script to set the _pluginName string
    	       //input : string;
               function SetPluginName(luaState : TLuaState) : integer;
    	       //this function provides the Lua script with the "colNames" array index containing the input string
    	       //input : string; output : number;
               function GetColumnIndex(luaState : TLuaState) : integer;
    	       //this function provides the Lua script with a two-dimensional array containing the "cells" 2D array
    	       //of TTGVNormalizedData _inputData
    	       //output : 2D array (rows,columns)
               function GetInputData(luaState : TLuaState) : integer;
    	       //this function allows the Lua script to set the "cells" 2D array of TTGVNormalizedData _outputData
    	       //input : 2D array (rows,columns);
               function SetOutputData(luaState : TLuaState) : integer;
    	       //this function allows the Lua script to define the "colNames" array of TTGVNormalizedData _outputData
    	       //input : string array;
               function SetOutputColumnNames(luaState : TLuaState) : integer;
    	       //this function provides an array containing the list of keys from TTGVPluginSetup
               function GetVarKeys(luaState : TLuaState) : integer;
    	       //this function provides an array containing the list of values from TTGVPluginSetup
               function GetVarValues(luaState : TLuaState) : integer;
    	       //this function provides a string containing the value associated with the input key
    	       //input : key(string);
               function GetVar(luaState : TLuaState) : integer;
    	       //this function outputs a Lua string containing "hello!"
               function SayHello(luaState : TLuaState) : integer;
         public
               constructor Create(const inp : TTGVNormalizedData; const ps : TTGVPluginSetup; const luaLib : string = '');
               destructor Destroy; override;

               function Execute : boolean;

               property PluginName : PChar read GetPluginName;
               property OutputData : TTGVNormalizedData read _outputData;
               property Error: string read _errorStr;
    end;



implementation

//A small function to quickly check if two strings match
function StringMatch(const reference : ansistring; const challenger : ansistring;
                     matchType : EMatchType; var curPos : cardinal) : boolean; register;
begin
     Result := false;
     curPos := pos(reference, challenger);
     case matchType of
         PARTIAL_MATCH: if curPos <> 0 then Result := true;
         PERFECT_MATCH: if (curPos = 1) and (length(reference) = length(challenger)) then Result := true;
         INCLUSION_MATCH: if curPos = 1 then Result := true;
     end;
end;

function TTGVFilterPlugin.ReturnColIndex(const colName : string) : cardinal;
var i,j : cardinal;
begin
     Result := 0;
     if (_inputData.colCount = 0) or (_inputData.rowCount = 0) then exit;
     for i := 0 to length(_inputData.colNames) - 1 do
     begin
          if StringMatch(colName,_inputData.colNames[i],PARTIAL_MATCH,j) then
              exit(i);
     end;
end;


//Important : the LuaLib string should point to the Lua 5.2.1 SO/DLL file.
constructor TTGVFilterPlugin.Create(const inp : TTGVNormalizedData; const ps : TTGVPluginSetup; const luaLib : string = '');
begin
     _pluginName := ps.pluginName;
     _errorStr   := '';
     _ps         := ps;
     _inputData  := inp;
     if not Lua.libLoaded then
          if not Lua.LoadLuaLibrary(luaLib) then
               _errorStr := Lua.errorString;

     if _errorStr <> '' then
          exit;

     _lua        := TLua.Create;
     luaL_openlibs(_lua.LuaInstance);

     _lua.RegisterFunction('SetPluginName','SetPluginName',self);
     _lua.RegisterFunction('GetVarKeys','GetVarKeys',self);
     _lua.RegisterFunction('GetVarValues','GetVarValues',self);
     _lua.RegisterFunction('GetVar','GetVar',self);
     _lua.RegisterFunction('GetInputData','GetInputData',self);
     _lua.RegisterFunction('SetOutputData','SetOutputData',self);
     _lua.RegisterFunction('SetOutputColumnNames','SetOutputColumnNames',self);
     _lua.RegisterFunction('GetColumnIndex','GetColumnIndex',self);
     _lua.RegisterFunction('SayHello','SayHello',self);
     lua_gc(_lua.LuaInstance, LUA_GCRESTART, 0);
end;


destructor TTGVFilterPlugin.Destroy;
var i,j : longint;
begin
     setLength(_outputData.title,0);
     setLength(_inputData.title,0);
     _inputData.rowCount:= 0;
     _inputData.colCount:= 0;
     _inputData.index   := 0;
     _outputData.rowCount:= 0;
     _outputData.colCount:= 0;
     _outputData.index   := 0;

     for i:= 0 to length(_outputData.cells)-1 do
     begin
          if i<length(_outputData.colNames) then
               setLength(_outputData.colNames[i],0);

          for j:=0 to length(_outputData.cells[i])-1 do
               setLength(_outputData.cells[i,j],0);

          setLength(_outputData.cells[i],0);
     end;
     for i:= 0 to length(_inputData.cells)-1 do
     begin
          if i<length(_inputData.colNames) then
               setLength(_inputData.colNames[i],0);

          for j:=0 to length(_inputData.cells[i])-1 do
               setLength(_inputData.cells[i,j],0);

          setLength(_inputData.cells[i],0);
     end;

     setLength(_outputData.colNames,0);
     setLength(_inputData.colNames,0);

     lua_gc(_lua.LuaInstance, LUA_GCCOLLECT, 0);
     _lua.UnregisterFunctions(self);

     _lua.Destroy;
end;


function TTGVFilterPlugin.GetPluginName : PChar;
begin
     Result := PChar(_pluginName);
end;


function TTGVFilterPlugin.Execute : boolean;
begin
     try
       if luaL_loadfile(_lua.LuaInstance,PAnsiChar(_ps.pluginName)) <> 0 then
            raise Exception.Create('cannot load file "'+_ps.pluginName+'".');

       case lua_pcall(_lua.LuaInstance, 0, LUA_MULTRET, 0) of
            LUA_ERRRUN    :
            begin
                 raise Exception.Create('Lua : runtime error in "'+_ps.pluginName+'"');
            end;
            LUA_ERRMEM    :
            begin
                 raise Exception.Create('Lua : memory allocation error in "'+_ps.pluginName+'"');
            end;
            LUA_ERRSYNTAX :
            begin
                 raise Exception.Create('Lua : syntax error in "'+_ps.pluginName+'"');
            end;
            LUA_ERRERR    :
            begin
                 raise Exception.Create('Lua : error handling function failed in "'+_ps.pluginName+'"');
            end;
       end;

       Result := true;
     except
       on E:Exception do
       begin
            _errorStr := E.Message + ' : ' + lua_tostring(_lua.LuaInstance, -1);
            Result := false;
       end;
     end;
end;


function TTGVFilterPlugin.SetPluginName(luaState : TLuaState) : integer;
begin
     _pluginName := Lua_toString(luaState, 1);
     // Clear stack
     Lua_Pop(luaState, Lua_GetTop(luaState));
     Result := 0;
end;


function TTGVFilterPlugin.GetColumnIndex(luaState : TLuaState) : integer;
var i : cardinal;
begin
     i := ReturnColIndex(lua_toString(luaState, 1));
     // Clear stack
     Lua_Pop(luaState, Lua_GetTop(luaState));
     lua_pushInteger(luaState,i);
     Result := 1;
end;


function TTGVFilterPlugin.GetInputData(luaState : TLuaState) : integer;
var
    i,j          : longint;
begin
     // Clear stack
     Lua_Pop(luaState, Lua_GetTop(luaState));

     try
       if (_inputData.rowCount = 0) or (_inputData.colCount = 0) then
            raise Exception.Create('no input data available!');

       //creates outer table
       lua_createTable(luaState,_inputData.rowCount,0);
       for i := 0 to _inputData.rowCount-1 do
       begin
            //creates inner table
            lua_createTable(luaState,_inputData.colCount,0);

            for j := 0 to _inputData.colCount-1 do
            begin
                 lua_pushString(luaState, PAnsiChar(_inputData.cells[i,j]));
                 lua_rawseti(luaState,-2,j);
            end;

            //puts the inner table in the outer table
            lua_rawseti(luaState,-2,i);
       end;
       //sets the name of the outer table
       lua_setglobal(luaState,'inputData');

       lua_pushboolean(luaState, 1);
       Result := 1;
     except
       on E:Exception do
       begin
            _errorStr := E.Message;
            lua_pushboolean(luaState, 0);
            Result := 1;
       end;
     end;
end;


function TTGVFilterPlugin.SetOutputData(luaState : TLuaState) : integer;
var
    i,j       : cardinal;
    curPos    : cardinal;
begin
     i := 0;
     if lua_istable(luaState,1) then
     begin
          //getting the last item index in the table
          lua_len(luaState,1);
          _outputData.rowCount := lua_tointeger(luaState,-1) + 1;

          //getting the last item index in the first row
          lua_rawgeti(luaState,1,0);
          lua_len(luaState,-1);
          _outputData.colCount := lua_tointeger(luaState,-1) + 1;

          setLength(_outputData.cells,_outputData.rowCount);

          for i := 0 to _outputData.rowCount - 1 do
          begin
               lua_rawgeti(luaState,1,i);
               setLength(_outputData.cells[i],_outputData.colCount);
               for j := 0 to _outputData.colCount - 1 do
               begin
                    lua_rawgeti(luaState,-1,j);
                    case lua_type(LuaState,-1) of
                        LUA_TNUMBER:
                             _outputData.cells[i,j] := FloatToStr(Lua_tonumber(luaState, -1));
                        LUA_TSTRING:
                             _outputData.cells[i,j] := Lua_tostring(LuaState, -1);
                        LUA_TBOOLEAN:
                             _outputData.cells[i,j] := BoolToStr(ByteBool(Lua_toboolean(luaState, -1)),'true','false');
                    end;
                    lua_pop(luaState,1);
               end;
               lua_pop(luaState,1);
          end;

     end;

     // Clear stack
     Lua_Pop(luaState, Lua_GetTop(luaState));
     Lua_PushBoolean(luaState, 1);
     Result := 1;
end;


function TTGVFilterPlugin.SetOutputColumnNames(luaState : TLuaState) : integer;
var
   count, i : cardinal;
begin
     count := 0;
     if lua_istable(luaState,1) then
     begin
          //getting the last item index in the table
          lua_len(luaState,1);
          count := lua_tointeger(luaState,-1) + 1;
     end;

     if (_outputData.colCount = 0) or (_outputData.colCount < count) or (count = 0) then
     begin
          // Clear stack
          lua_Pop(luaState, lua_getTop(luaState));
          lua_pushBoolean(luaState, 0);
          exit(1);
     end;

     setLength(_outputData.colNames,_outputData.colCount);
     for i := 0 to _outputData.colCount - 1 do
     begin
          if (i >= count) then
               _outputData.colNames[i] := ''
          else
          begin
               lua_rawgeti(luaState,1,i);
               case lua_type(LuaState,-1) of
                   LUA_TNUMBER:
                        _outputData.colNames[i] := FloatToStr(Lua_toNumber(luaState, -1));
                   LUA_TSTRING:
                        _outputData.colNames[i] := Lua_toString(LuaState, -1);
                   LUA_TBOOLEAN:
                        _outputData.colNames[i] := BoolToStr(ByteBool(Lua_toBoolean(luaState, -1)),'true','false');
               end;
               lua_pop(luaState,1);
          end;

     end;

     // Clear stack
     lua_pop(luaState, lua_GetTop(luaState));
     lua_pushBoolean(luaState, 1);
     Result := 1;
end;


function TTGVFilterPlugin.GetVarKeys(luaState : TLuaState) : integer;
var
    i : longint;
begin
     // Clear stack
     Lua_Pop(luaState, Lua_GetTop(luaState));

     if (length(_ps.pluginKeys) = 0) then
     begin
          _errorStr := 'no variable names available!';
          lua_pushboolean(luaState, 0);
          exit(1);
     end;

     //creates outer table
     lua_createTable(luaState,length(_ps.pluginKeys), 0);
     for i := 0 to length(_ps.pluginKeys) -1 do
     begin
          lua_pushString(luaState, PAnsiChar(_ps.pluginKeys[i]));
          lua_rawseti(luaState,-2,i);
     end;

     //sets the name of the outer table
     lua_setglobal(luaState,PAnsiChar('varKeys'));

     lua_pushboolean(luaState, 1);
     Result := 1;
end;


function TTGVFilterPlugin.GetVarValues(luaState : TLuaState) : integer;
var
    i : longint;
begin
     // Clear stack
     Lua_Pop(luaState, Lua_GetTop(luaState));

     if (length(_ps.pluginValues) = 0) then
     begin
          _errorStr := 'no variable contents available!';
          lua_pushboolean(luaState, 0);
          exit(1);
     end;

     //creates outer table
     lua_createTable(luaState,length(_ps.pluginValues),0);
     for i := 0 to length(_ps.pluginValues) -1 do
     begin
          lua_pushString(luaState, PAnsiChar(_ps.pluginValues[i]));
          lua_rawseti(luaState,-2,i);
     end;

     //sets the name of the outer table
     lua_setglobal(luaState,'varValues');

     lua_pushboolean(luaState, 1);
     Result := 1;
end;


function TTGVFilterPlugin.GetVar(luaState : TLuaState) : integer;
var
    i : longint;
    j : cardinal;
    key,str : string;
begin
     if (length(_ps.pluginValues) < length(_ps.pluginKeys)) or (length(_ps.pluginKeys) = 0) then
     begin
          // Clear stack
          lua_pop(luaState, lua_getTop(luaState));
          lua_pushString(luaState,PAnsiChar(''));
          exit(1);
     end;

     key := lua_toString(luaState,1);
     UpString(key,key);

     for i := 0 to length(_ps.pluginKeys) -1 do
     begin
          str := _ps.pluginKeys[i];
          UpString(str,str);
          if StringMatch(key,str,PERFECT_MATCH,j) then
          begin
               // Clear stack
               lua_pop(luaState, lua_getTop(luaState));
               lua_pushString(luaState,PAnsiChar(_ps.pluginValues[i]));
               exit(1);
          end;
     end;

     // Clear stack
     lua_pop(luaState, lua_getTop(luaState));
     lua_pushString(luaState,PAnsiChar(''));
     exit(1);
end;


function TTGVFilterPlugin.SayHello(luaState : TLuaState) : integer;
begin
     // Clear stack
     Lua_Pop(luaState, Lua_GetTop(luaState));
     lua_pushstring(luaState,PAnsiChar('hello!'));
     Result := 1;
end;


end.

