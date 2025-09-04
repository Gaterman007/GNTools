#-----------------------------------------------------------------------------
# Copyright 2022, Gaetan Noiseux, based loosely on linetool.rb by @Last Software, Inc.
#  load "C:/Users/Gaetan/Documents/Sketchup/GN3DPrinterCNC.rb"
# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#-----------------------------------------------------------------------------
require 'fiddle'
require 'fiddle/import'
require 'fiddle/types'
require 'sketchup.rb'



module Win32API2
    
	module ComDlg32
		
	  extend Fiddle::Importer
	  
      dlload 'Comdlg32'
      include Fiddle::Win32Types

	  typealias 'LPCWSTR', 'const wchar_t*' 
	  typealias 'LPWSTR', 'wchar_t*' 

	  OpenFileName = struct [
		'DWORD          lStructSize',
		'void*           hwndOwner',
		'HINSTANCE      hInstance',
		'LPCWSTR        lpstrFilter',
		'LPWSTR         lpstrCustomFilter',
		'DWORD          nMaxCustFilter',
		'DWORD          nFilterIndex',
		'LPWSTR         lpstrFile',
		'DWORD          nMaxFile',
		'LPWSTR         lpstrFileTitle',
		'DWORD          nMaxFileTitle',
		'LPCWSTR        lpstrInitialDir',
		'LPCWSTR        lpstrTitle',
		'DWORD          Flags',
		'WORD           nFileOffset',
		'WORD           nFileExtension',
		'LPCWSTR        lpstrDefExt',
		'long long      lCustData',
		'void * 		lpfnHook',
		'LPCWSTR        lpTemplateName',
		'void *        	pvReserved',
		'DWORD        	dwReserved',
		'DWORD        	FlagsEx'
		]
	
	
      # https://learn.microsoft.com/en-us/windows/win32/api/commdlg/nf-commdlg-getopenfilenamew
      #
	  # Creates an Open dialog box that lets the user specify the drive, directory, and the name of a file or set of files to be opened.
#		BOOL GetOpenFileNameW([in, out] LPOPENFILENAMEW unnamedParam1);
	  # LPOPENFILENAMEW
      # A pointer to a OPENFILENAME structure that set the information for the dialog.
	  extern 'BOOL GetOpenFileName(void*)'

      # https://https://learn.microsoft.com/en-us/windows/win32/api/commdlg/nf-commdlg-getsavefilenamew
      #
	  # Creates an Open dialog box that lets the user specify the drive, directory, and the name of a file or set of files to be opened.
#		BOOL GetOpenFileNameW([in, out] LPOPENFILENAMEW unnamedParam1);
	  # LPOPENFILENAMEW
      # A pointer to a OPENFILENAME structure that set the information for the dialog.
	  extern 'BOOL GetSaveFileName(void*)'


	  extern 'DWORD CommDlgExtendedError()'

	end
	
    module User32

      # Copied from the WinUser.h header
      CF_TEXT = 1

      extend Fiddle::Importer

      dlload 'User32'
      include Fiddle::Win32Types

      CursorPoint = struct [
        # The x-coordinate of the point.
        'long x',
        # The x-coordinate of the point.
        'long y'
      ]


      # https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getcursorpos
      #
      # Retrieves the position of the mouse cursor, in screen coordinates.
      # Parameters
      # lpPoint
      #
      # Type: LPPOINT
      #
      # A pointer to a POINT structure that receives the screen coordinates of the cursor.
      #
      # Return value
      # Type: BOOL
      #
      # Returns nonzero if successful or zero otherwise. To get extended error information, call GetLastError.
      #
      extern 'BOOL GetCursorPos(CursorPoint*)'
      
      
      # https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setcursorpos
      
      # Moves the cursor to the specified screen coordinates. If the new coordinates are not within the screen rectangle 
      # set by the most recent ClipCursor function call, the system automatically adjusts the coordinates 
      # so that the cursor stays within the rectangle.
      #       
      # Parameters
      # X
      # Type: int
      # 
      # The new x-coordinate of the cursor, in screen coordinates.
      # Y
      # Type: int
      # 
      # The new y-coordinate of the cursor, in screen coordinates.
      # 
      # Return value
      # Type: BOOL
      # 
      # Returns nonzero if successful or zero otherwise. To get extended error information, call GetLastError.
      # 
      # Remarks
      # The cursor is a shared resource. A window should move the cursor only when the cursor is in the window's client area.
      extern 'BOOL SetCursorPos(int,int)'
      
      # https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-openclipboard
      #
      # A handle to the window to be associated with the open clipboard. If this
      # parameter is NULL, the open clipboard is associated with the current task.
      #
      # Return: 0 = error; non-0 = success
      #
      # BOOL OpenClipboard(
      #   HWND hWndNewOwner
      # );
      extern 'BOOL OpenClipboard(HWND)'

      # https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-closeclipboard
      # Return: 0 = error; non-0 = success
      #
      # BOOL CloseClipboard();
      extern 'BOOL CloseClipboard()'

      # https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-emptyclipboard
      # Return: 0 = error; non-0 = success
      #
      # BOOL EmptyClipboard();
      extern 'BOOL EmptyClipboard()'

      # https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getclipboarddata
      # Return: NULL upon failure
      #
      # uFormat
      #   https://docs.microsoft.com/en-us/windows/win32/dataxchg/clipboard-formats
      #
      # HANDLE GetClipboardData(
      #   UINT uFormat
      # );
      extern 'HANDLE GetClipboardData(UINT)'

      # https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-setclipboarddata
      # Return: If the function succeeds, the return value is the handle to the
      #         data.
      #
      #         If the function fails, the return value is NULL. To get extended
      #         error information, call GetLastError.
      #
      # HANDLE SetClipboardData(
      #   UINT   uFormat,
      #   HANDLE hMem
      # );
      extern 'HANDLE SetClipboardData(UINT, HANDLE)'

      # https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getmenu
      # Return: The return value is a handle to the menu. 
	  # 				If the specified window has no menu, the return value is NULL. 
      # 				If the window is a child window, the return value is undefined.
      #
      # HMENU GetMenu(
      #   HWND   hwnd
      # );
      extern  'HANDLE GetMenu(HWND)'


      # https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getmenu
      # Return: The return value is a handle to the menu. 
	  # 				If the specified window has no menu, the return value is NULL. 
      # 				If the window is a child window, the return value is undefined.
      #
      # HWND GetActiveWindow();
  	  extern 'HANDLE GetActiveWindow()'

      # https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getmenu
      # Return: 
      # int GetWindowTextA(
      #   [in]  HWND  hWnd,
      #   [out] LPSTR lpString,
      #   [in]  int   nMaxCount
      # );
      # 
	  extern 'int GetWindowText(HANDLE,LPSTR,int)'


      # https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getmenu
      # Return: 
      # int GetWindowTextLengthA(
      #   [in] HWND hWnd
      # );
	  extern 'int GetWindowTextLength(HANDLE)'

      # https://docs.microsoft.com/en-us/windows/win32/api/winuser/nf-winuser-getmenuitemcount
      # Return: If the function succeeds, the return value specifies the number of items in the menu.
      # If the function fails, the return value is -1. To get extended error information, call GetLastError.
	  extern 'int GetMenuItemCount(HANDLE)'
	  
      MenuItemInfo = struct [
		'long cbSize',
		'long fMask',
		'long fType',
		'long fState',
		'long wID',
		'HANDLE     hSubMenu',
		'HANDLE   hbmpChecked',
		'HANDLE   hbmpUnchecked',
		'unsigned long dwItemData',
		'char*     dwTypeData',
		'long cch',
		'HANDLE   hbmpItem'
      ]
	  
	  extern 'BOOL GetMenuItemInfo(HANDLE,UINT,BOOL,MenuItemInfo*)'
    end
    
    module CursorPos
    # Doing this to be able to hide internal methods from the Clipboard
    # public interface.
        class << self
    
            include User32
        
            def setcursorpos(x,y)
                retval = User32.SetCursorPos(x,y)
            end

            def getcursorpos(pointarrayptr)
                pointpos = CursorPoint.malloc
                retval = User32.GetCursorPos(pointpos)
                retpointst = CursorPoint.new(pointpos)
#                puts "point array #{retpointst.x},#{retpointst.y}"
                pointarrayptr = [retpointst.x,retpointst.y]
#                puts "point array #{pointarrayptr}"
#                retval
            end
        end
    end

    module Menus
    # Doing this to be able to hide internal methods from the Clipboard
    # public interface.
        class << self
    
            include User32
        
            def getMenuItemCount()
				mainHandle = User32.GetActiveWindow
				retval = User32.GetMenuItemCount(User32.GetMenu(mainHandle))
            end

            def getMenuItem(menuindex)
				mainHandle = User32.GetActiveWindow
				menutext = '                                                                                                                                                                        '
                menuItemInfo = MenuItemInfo.malloc
#				p MenuItemInfo.size
				menuItemInfo.cbSize = MenuItemInfo.size
				menuItemInfo.fMask = 0
				menuItemInfo.fType = 0
				menuItemInfo.fState = 0
				menuItemInfo.wID = 0
				menuItemInfo.hSubMenu = 0
				menuItemInfo.hbmpChecked = 0
				menuItemInfo.hbmpUnchecked = 0
				menuItemInfo.dwItemData = 0
				menuItemInfo.dwTypeData = 0
				menuItemInfo.cch = 0
				menuItemInfo.hbmpItem = 0
				menuItemInfo.fMask = 0x00000040
				menuItemInfo.fType = 0x00000000
				menuItemInfo.dwTypeData = menutext
				menuItemInfo.cch = 128
                retval = User32.GetMenuItemInfo(mainHandle,menuindex,1,menuItemInfo)
				retmenuItemInfost = MenuItemInfo.new(menuItemInfo)
				ssize = menuItemInfo.cch + 1
				p 'string size'
				p menuItemInfo.cch
				p retmenuItemInfost.cch
				menuItemInfo.cch = ssize
				menuItemInfo.dwTypeData = menutext
                retval = User32.GetMenuItemInfo(mainHandle,menuindex,1,menuItemInfo)
				p 'string'
				p menuItemInfo.dwTypeData
                retmenuItemInfost = MenuItemInfo.new(menuItemInfo)
#                puts "point array #{retpointst.x},#{retpointst.y}"
                menuStr = retmenuItemInfost.dwTypeData
				p 'string'
#				puts menuStr
#                puts "point array #{pointarrayptr}"
#                retval
            end
        end
    end
	module FileName
    # Doing this to be able to hide internal methods from the Clipboard
    # public interface.
        class << self
    
            include ComDlg32
			
			# OFN_PATHMUSTEXIST 0x00000800
			# OFN_FILEMUSTEXIST 0x00001000
			def getOpenFileName()
				buffer_size = 1024
				szFile_buffer_buff = "testfile"
				szFile_buffer = Fiddle::Pointer.malloc(buffer_size * 2) # Two bytes per wchar_t
				# Use Fiddle's memset function to set the memory to zero bytes
#				szFile_buffer = szFile_buffer_buff.encode('UTF-16LE', 'UTF-8', invalid: :replace, undef: :replace, replace: '?')
#p szFile_buffer
                openFileName = ComDlg32::OpenFileName.malloc
				mainHandle = User32.GetActiveWindow
				openFileName.lStructSize = OpenFileName.size
				openFileName.hwndOwner = 0
				openFileName.hInstance = 0
				openFileName.lpstrFilter = 0
				openFileName.lpstrCustomFilter = 0
				openFileName.nMaxCustFilter = 0
				openFileName.nFilterIndex = 0
				openFileName.lpstrFile = 0
				openFileName.nMaxFile = 0
				openFileName.lpstrFileTitle = 0
				openFileName.nMaxFileTitle = 0
				openFileName.lpstrInitialDir = 0
				openFileName.lpstrTitle = 0
				openFileName.Flags = 0
				openFileName.nFileOffset = 0
				openFileName.nFileExtension = 0
				openFileName.lpstrDefExt = 0
				openFileName.lCustData = 0
				openFileName.lpfnHook = 0
				openFileName.lpTemplateName = 0
				openFileName.pvReserved = 0
				openFileName.dwReserved = 0
				openFileName.FlagsEx = 0


				openFileName.hwndOwner = mainHandle
				openFileName.lpstrFile = szFile_buffer
				# Set lpstrFile[0] to '\0' so that GetOpenFileName does not 
				# use the contents of szFile_buffer to initialize itself.
				openFileName.lpstrFile[0] = 0
				openFileName.nMaxFile = buffer_size;
				openFileName.lpstrFilter = "All\0*.*\0Text\0*.TXT\0"
				openFileName.nFilterIndex = 1
				openFileName.lpstrFileTitle = 0
				openFileName.nMaxFileTitle = 0
				openFileName.lpstrInitialDir = 0
				openFileName.Flags = 0x00001800
				opened = ComDlg32::GetOpenFileName(openFileName)
				if opened == 0
				 p ComDlg32::CommDlgExtendedError()
				end
				fileName = openFileName.lpstrFile.to_s(buffer_size * 2).encode('UTF-8','UTF-16LE',invalid: :replace, undef: :replace, replace: '?')
##				fileName.gsub!("\x00", '')
				fileName
			end
			def getSaveFileName()
                openFileName = OpenFileName.malloc
				openFileName.lStructSize = OpenFileName.size
			end
			
		end # class self
	end # module FileName
end
