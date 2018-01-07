program luatest;

{$IFDEF FPC}
     {$mode objfpc}{$H+}
{$ENDIF}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, Lua;


var
   _lua  : TLua;
   error : boolean;
   luaFile: string;

const
     LUASOURCE = 'luatest.lua';
{$IFDEF UNIX}
{$IFDEF CPU64}
     LUALIBRARY = 'liblua52-64.so';
{$ELSE}
     LUALIBRARY = 'liblua52-32.so';
{$ENDIF}
{$ELSE}
{$IFDEF CPU64}
     LUALIBRARY = 'lua52-64.dll';
{$ELSE}
     LUALIBRARY = 'lua52-32.dll';
{$ENDIF}
{$ENDIF}


function Increment(luaState : TLuaState) : integer;
var i : longint;
begin
     //reads the first parameter passed to Increment as an integer
     i := Lua_toInteger(luaState, 1);

     //increments it
     inc(i);

     //clears current Lua stack
     Lua_Pop(luaState, Lua_GetTop(luaState));

     //pushes the incremented integer back to the Lua stack
     lua_pushInteger(luaState,i);
     //Result : number of results to give back to Lua
     Result := 1;
end;


(*============================= MAIN ROUTINE =================================*)
begin
     error := false;
     if ParamCount = 0 then
     begin
          luaFile := LUASOURCE;
     end
     else
          luaFile := Paramstr(1);

     //Tries loading the dynamic library file
     if not Lua.libLoaded then
          if not Lua.LoadLuaLibrary(LUALIBRARY) then
          begin
               writeln('Lua library could not load : ',Lua.errorString);
               error := true;
          end;

     if error then halt(1);

     //now creates the TLua manager class
     _lua := TLua.Create;
     //loads the standard Lua toolkits
     luaL_openlibs(_lua.LuaInstance);
     //activates the Garbage collector on the Lua side
     lua_gc(_lua.LuaInstance, LUA_GCRESTART, 0);

     _lua.RegisterFunction('Inc','Increment',nil,@Increment);

     try
       //now loads the lua script in memory
       if luaL_loadfile(_lua.LuaInstance,PAnsiChar(luaFile)) <> 0 then
            raise Exception.Create('cannot load file "'+luaFile+'".');

       //executes it, and catches any error returned by the Lua interpreter ...
       case lua_pcall(_lua.LuaInstance, 0, LUA_MULTRET, 0) of
            LUA_ERRRUN    :
            begin
                 raise Exception.Create('Lua : runtime error in "'+luaFile+'"');
            end;
            LUA_ERRMEM    :
            begin
                 raise Exception.Create('Lua : memory allocation error in "'+luaFile+'"');
            end;
            LUA_ERRSYNTAX :
            begin
                 raise Exception.Create('Lua : syntax error in "'+luaFile+'"');
            end;
            LUA_ERRERR    :
            begin
                 raise Exception.Create('Lua : error handling function failed in "'+luaFile+'"');
            end;
       end;

     except
       on E:Exception do
       begin
            writeln(E.Message + ' : ' + #10 + #09 + lua_tostring(_lua.LuaInstance, -1));
            writeln;
            writeln('Lua demo failed ...');
            _lua.Destroy;
            halt(1);
       end;
     end;

     //signals the garbage collector to start cleaning
     lua_gc(_lua.LuaInstance, LUA_GCCOLLECT, 0);
     //unregisters the function we loaded into the interpreter
     _lua.UnregisterFunctions(nil);
     //and frees the remaining memory
     _lua.Destroy;

     //that's all folks!
     writeln;
     writeln('Lua demo is successful!');
end.

