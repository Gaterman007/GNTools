#-----------------------------------------------------------------------------
# Copyright 2022, Gaetan Noiseux,
#  load "C:/Users/Gaetan/Documents/Sketchup/GN3DPrinterCNC.rb"
# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#-----------------------------------------------------------------------------
require 'fiddle'
require 'fiddle/import'
require 'fiddle/types'
require 'sketchup.rb'
require File.join(GNTools::PATH_TOOLS, "GN_CombineTool.rb")
require File.join(GNTools::PATH_TOOLS, "GN_materialTool.rb")

module GNTools


	class CommandClass
	
		attr_accessor :cmd_circle3x3Tool
		attr_accessor :cmd_Add_Material
		attr_accessor :cmdCNCTools
		attr_accessor :cmdCreatePath
		attr_accessor :cmdparamGCode
		attr_accessor :cmdGCode
        attr_accessor :cmdDemoMat
		
		def initialize
			@cmd_circle3x3Tool = UI::Command.new(GNTools.traduire("Circle From 3 Points")) { Sketchup.active_model.select_tool Circle3X3DPoints.new }
			@cmd_circle3x3Tool.tooltip = GNTools.traduire("Circle passing by 3 points.")
			@cmd_circle3x3Tool.status_bar_text = GNTools.traduire("3 points circle.")
#        		@cmd_circle3x3Tool.small_icon = File.join(GNTools::PATH_IMAGES, 'Inspector-16.png')
#        		@cmd_circle3x3Tool.large_icon = File.join(GNTools::PATH_IMAGES, 'Inspector-24.png')

			#---------------------------------
			# Command Menu addition de material
			#---------------------------------
			@cmd_Add_Material = UI::Command.new(GNTools.traduire('Add Material')) {
				@dialogMaterial = GNTools::MaterialDialog.new(nil)
			}

			@cmd_Add_Material.set_validation_proc {
				model = Sketchup.active_model
				selection = model.selection
				groups = selection.grep(Sketchup::Group)

				if groups.count == 1 && groups[0].manifold?
					MF_ENABLED
				else
					MF_GRAYED
				end
			}
			#		MF_ENABLED, MF_DISABLED, MF_CHECKED, MF_UNCHECKED, or MF_GRAYED
#			@cmdMaterial = UI::Command.new("Material") {GNTools::activate_Material}
			@cmd_Add_Material.small_icon = File.join(GNTools::PATH_IMAGES,"PlayCncLarge.png")
			@cmd_Add_Material.large_icon = File.join(GNTools::PATH_IMAGES,"PlayCncSmall.png")
			@cmd_Add_Material.tooltip = "Add Material"
			@cmd_Add_Material.status_bar_text = "Add Material"
			@cmd_Add_Material.menu_text = "Add Material"		
			
			@cmdCNCTools = UI::Command.new("AddPath") {GNTools::activate_CreateTool}
			@cmdCNCTools.small_icon = File.join(GNTools::PATH_IMAGES,"HoleSmallPlus.png")
			@cmdCNCTools.large_icon = File.join(GNTools::PATH_IMAGES,"HoleLargePlus.png")
			@cmdCNCTools.tooltip = "CNC Add"
			@cmdCNCTools.status_bar_text = "CNC Add"
			@cmdCNCTools.menu_text = "CNC Add"
			@cmdCNCTools.set_validation_proc {
			  GNTools::ObserverModule.hasCircle = false
			  GNTools.verifieSelection(Sketchup.active_model.selection)
#			  if GNTools.materialList.count != 0
				  if Sketchup.active_model.selection.length != 0 && (GNTools::ObserverModule.hasCircle || GNTools::ObserverModule.hasEdges|| GNTools::ObserverModule.hasFaces)
					MF_ENABLED
				  else
					MF_GRAYED
				  end
#			  else
#				MF_GRAYED
#			  end
			}
			@cmdCreatePath = UI::Command.new("CreatePath") {GNTools::activate_PathTool}
			@cmdCreatePath.small_icon = File.join(GNTools::PATH_IMAGES,"HoleSmall.png")
			@cmdCreatePath.large_icon = File.join(GNTools::PATH_IMAGES,"HoleLarge.png")
			@cmdCreatePath.tooltip = "CNC Tool"
			@cmdCreatePath.status_bar_text = "CNC Tool"
			@cmdCreatePath.menu_text = "CNC Tool"
			@cmdCreatePath.set_validation_proc {
#			  if GNTools.materialList.count != 0
				if Sketchup.active_model.selection.length == 0 # && GNTools::ObserverModule.allEdges
					MF_GRAYED
				else
					MF_ENABLED
				end
#			  else
#				MF_GRAYED
#			  end
			}


			@cmdparamGCode = UI::Command.new("GCode") {GNTools::activate_defaultCNCTool}
			@cmdparamGCode.small_icon = File.join(GNTools::PATH_IMAGES,"MaterialParamSmall.png")
			@cmdparamGCode.large_icon = File.join(GNTools::PATH_IMAGES,"MaterialParam.png")
			@cmdparamGCode.tooltip = "Parameters GCode"
			@cmdparamGCode.status_bar_text = "Parameters GCode"
			@cmdparamGCode.menu_text = "Parameters GCode"

			@cmdGCode = UI::Command.new("GCode") {GCodeGenerate.SaveAs}
			@cmdGCode.small_icon = File.join(GNTools::PATH_IMAGES,"GcodeSmall.png")
			@cmdGCode.large_icon = File.join(GNTools::PATH_IMAGES,"GcodeLarge.png")
			@cmdGCode.tooltip = "Generate GCode"
			@cmdGCode.status_bar_text = "Generate GCode"
			@cmdGCode.menu_text = "Generate GCode"

        
			@cmdDemoMat = UI::Command.new("DemoMateriel") {GNTools::activate_defaultCNCTool}
			@cmdDemoMat.small_icon = File.join(GNTools::PATH_IMAGES,"DemoMaterielSmall.png")
			@cmdDemoMat.large_icon = File.join(GNTools::PATH_IMAGES,"DemoMaterielLarge.png")
			@cmdDemoMat.tooltip = "Generate Demo"
			@cmdDemoMat.status_bar_text = "Generate Demo"
			@cmdDemoMat.menu_text = "Generate Demo"



		end	# initialize
	end		# class


	@@combineTool = Paths::CombineTool.new()
	@@defaultCNCTool = GNTools::DefaultCNCTool.new()
	@@activeToolID = nil
	@@commandClass = GNTools::CommandClass.new()


	def self.commandClass
		@@commandClass
	end

	def self.combineTool
		@@combineTool
	end

	def self.activeToolID
		@@activeToolID
	end

	def self.activeToolID=(value)
		@@activeToolID = value
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
	
	
    def self.activate_line_tool
      Sketchup.active_model.select_tool(LineTool.new)
#	  p self.getWindowName
    end
    	
	def self.activate_PathTool
		Sketchup.active_model.tools.push_tool(GNTools::combineTool)
	end
	
	def self.activate_CreateTool
		select = Sketchup.active_model.selection
		circles = GNTools.verifieSelection(select)
		edges = select.grep(Sketchup::Edge)
		if circles.count > 0
			circles.each do |circle|
				defaultHoleData = GNTools::Paths::CombineDialog.defaultHoleData
				defaultHoleData["holesize"] = circle.radius.to_mm * 2.0
				hash = {}
				defaultHoleData.to_Hash(hash)
				Sketchup.active_model.start_operation('createHole', true)
				GNTools::Paths::Hole.Create(circle.center,hash)
				Sketchup.active_model.commit_operation
			end
		end
		defaultStraitCutData = GNTools::Paths::CombineDialog.defaultStraitCutData
		defaultPocketData = GNTools::Paths::CombineDialog.defaultPocketData
		if edges.count > 0
			edges.each do |edge|
				if not (edge.is_a?(Sketchup::Edge) && edge.curve && edge.curve.is_a?(Sketchup::ArcCurve))
					line = [edge.start.position,edge.end.position]
					hash = {}
					defaultStraitCutData.to_Hash(hash)
					Sketchup.active_model.start_operation('createLine', true)
					GNTools::Paths::StraitCut.Create(line,hash)
					Sketchup.active_model.commit_operation
				end
			end
		end
		faces = select.grep(Sketchup::Face)
		if faces.count > 0
			hash = {}
			defaultPocketData.to_Hash(hash)
			Sketchup.active_model.start_operation(GNTools.traduire('createPocket'), true)
			GNTools::Paths::Pocket.Create(faces,hash)
			Sketchup.active_model.commit_operation
		end


	end
	
	def self.activate_Material
		@dialogMaterial = GNTools::MaterialDialog.new(nil)
	end

	def self.activate_defaultCNCTool
		Sketchup.active_model.select_tool(@@defaultCNCTool)
	end


    def self.activate_GCodeGenerate
       GCodeGenerate.generateGCode2
	end

	def self.create_Menus
	    plugins_menu = UI.menu('Plugins')

		submenu = plugins_menu.add_submenu(GNTools.traduire("CNC Menu"))
		submenu.add_item(GNTools::commandClass.cmd_Add_Material)
		submenu.add_item(GNTools.traduire('Material Default')) {
			self.activate_defaultCNCTool
		}
		submenu.add_item(GNTools.traduire('DrillBits')) {
			GNTools::DrillBits.show
		}
		submenu.add_item(GNTools.traduire('GCode Generate')) {
			self.activate_GCodeGenerate
		}
		submenu.add_item(GNTools.traduire('Save GCode to File')) {
			self.activate_SaveGCode
		}
		plugins_menu.add_item(GNTools.traduire('Construction Line')) {
			self.activate_line_tool
		}
		plugins_menu.add_item(GNTools::commandClass.cmd_circle3x3Tool)
        plugins_menu.add_item(GNTools::commandClass.cmdDemoMat)
		plugins_menu.add_item(GNTools.traduire("Reload GNTools")){
			self.reload 
		}
	end
	
    def self.reload()
        original_verbose = $VERBOSE
        $VERBOSE = nil
        # GN_ToolSet file (this)
        load 'GNTools.rb'
        SKETCHUP_CONSOLE.clear
        if defined?(PATH) && File.exist?(PATH)
            x = Dir.glob(File.join(PATH, "**/*.{rb,rbs}")).each { |file|
                load file
            }
            x.length + 1
        else
            1
        end
		DrillBits.loadFromFile(File.join(PATH, "DrillBits.txt"))
		initCNCGCode
		ObserverModule.reload
    ensure
        $VERBOSE = original_verbose
    end
end
