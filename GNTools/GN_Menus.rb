#-----------------------------------------------------------------------------
# Copyright 2022, Gaetan Noiseux,
#  load "C:/Users/Gaetan/Documents/Sketchup/GN_command_class.rb"
# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#-----------------------------------------------------------------------------
require 'fiddle'
require 'fiddle/import'
require 'fiddle/types'
require 'sketchup.rb'
require File.join(GNTools::PATH_TOOLS, "GN_ToolPath.rb")
require File.join(GNTools::PATH_TOOLS, "GN_materialTool.rb")
require File.join(GNTools::PATH_TOOLS, "GN_OctoPrintDialog.rb")
require File.join(GNTools::PATH_TOOLS, "octoPrint.rb")

module GNTools


  class GNMenu

    # getter : accès sans instancier
    def self.menu
      @menu
    end

    # créer le menu et le sous-menu CNC
    def self.load
      return if @loaded  # empêche duplication

      plugins_menu = UI.menu('Plugins') #return Menu Objet
      @menu ||= plugins_menu.add_submenu(GNTools.traduire("CNC Menu")) 	#return Menu Objet pour le sous menu

      # items du sous-menu
      @menu.add_item(GNTools::commandClass.cmd_OctoPrint)				# retour un integer
      @menu.add_item(GNTools::commandClass.cmd_Add_Material)			# retour un integer
      @menu.add_item(GNTools::commandClass.cmdparamGCode)				# retour un integer
      @menu.add_item(GNTools::commandClass.cmdDrillBits)				# retour un integer
      @menu.add_item(GNTools.traduire('GCode Generate')) {				# retour un integer
        GNTools.activate_GCodeGenerate
      }
      @menu.add_item(GNTools::commandClass.cmdSaveGCode)				# retour un integer

      # items dans le menu Plugins
      plugins_menu.add_item(GNTools::commandClass.cmdConstructionLine)	# retour un integer
      plugins_menu.add_item(GNTools::commandClass.cmd_circle3x3Tool)	# retour un integer
      plugins_menu.add_item(GNTools::commandClass.cmdDemoMat)			# retour un integer
      plugins_menu.add_item(GNTools.traduire("Reload GNTools")) {		# retour un integer
        self.reload
      }

      @loaded = true
    end

    # cacher et reconstruire proprement
    def self.reload
      # SketchUp ne fournit pas de remove_menu, donc recréation
      @menu = nil
      @loaded = false
      load
    end
	
	# --- Méthode de test pour modifier un item ---
  end


  def self.initMenu
	# Initialisation unique des singletons
	unless defined?(@@menu_initialized) && @@menu_initialized
	  require File.join(GNTools::PATH_TOOLS, "GN_PathObjUtils.rb")
	  require File.join(GNTools::PATH_ROOT, "GN_command_class.rb")
	  @@defaultCNCTool = GNTools::DefaultCNCTool.new()
	  @@activeToolID = nil
	  @@commandClass = GNTools::CommandClass.new()
	  @@menu_initialized = true
	  @@octoPrint = GNTools::OctoPrint.new()
	end
  end

  def self.getCursorPos
    pointarray = []
    Win32API2::CursorPos.getcursorpos(pointarray)        
  end

  def self.setCursorPos(pointXY)
    succes = Win32API2::CursorPos.setcursorpos(pointXY[0],pointXY[1])        
  end
    
  def self.fixCursorDisplay
    setCursorPos(getCursorPos)
  end
    
  def self.getActiveWindow
	handle = Win32API2::GetActiveWindow
  end

  def self.getWindowName
	mainHandle = Win32API2::User32.GetActiveWindow
	size =  Win32API2::User32.GetWindowTextLength(mainHandle)
	text = '0'.rjust(size+3,'0')
	textsize = Win32API2::User32.GetWindowText(mainHandle,text,size+2) - 1
	menuCount = Win32API2::User32.GetMenuItemCount(Win32API2::User32.GetMenu(mainHandle))
	p menuCount
	Win32API2::Menus.getMenuItem(3)

	text[0..textsize]
  end
    	
  def self.create_Menus
	GNMenu.load
  end
	
  def self.reload()
    original_verbose = $VERBOSE
    $VERBOSE = nil
    # GN_ToolSet file (this)
    load 'GNTools.rb'
    SKETCHUP_CONSOLE.clear
    if defined?(PATH_ROOT) && File.exist?(PATH_ROOT)
      x = Dir.glob(File.join(PATH_ROOT, "**/*.{rb,rbs}")).each { |file|
        load file
      }
      x.length + 1
    else
            1
    end
	DrillBits.loadFromFile(File.join(PATH_ROOT, "DrillBits.txt"))
	initCNCGCode
	ObserverModule.reload
    ensure
      $VERBOSE = original_verbose
  end
end
