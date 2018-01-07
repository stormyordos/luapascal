This archive contains the current "stable" Lua 5.2.3 header unit (backwards compatible with 5.2.1-2). 
It should be taken "as is", without any guarantees that it will work as well as its C counterpart.
Of course, any comments or suggestions you might have are welcome, and you can contact me using the 
contact mail address rbaccino at hexnode dot net.

The archive is currently made of three parts : 
	- lua.pas : the current Lua 5.2.3 pascal port, with the added TLua manager class.

	- example.pas : a module from my upcoming open-source data mining utility making heavy use of both the lua unit and the TLua class. This should serve as a quick reference demonstrating some advanced functionalities : the TLua class, how to pass arguments from the Pascal code to Lua and back again.

	- the luatest folder : this folder contains a Lazarus project, luatest.lpi, which is a complete Delphi-compatible Freepascal project demonstrating the basics : initializing the Lua library, registering a simple integer incrementation function and cleaning up. Everything should work out of the box, and the code should be well commented.
			

Enjoy!
stormy_ordos