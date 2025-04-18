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
require 'GNTools/GN_CombineTool.rb'
require 'GNTools/GN_materialTool.rb'

module GNTools

	@@combineTool = Paths::CombineTool.new()
	@@defaultCNCTool = GNTools::DefaultCNCTool.new()
	@@activeToolID = nil
	@@materialTool = GNTools::MaterialTool.new()

	def self.combineTool
		@@combineTool
	end

	def self.activeToolID
		@@activeToolID
	end

	def self.activeToolID=(value)
		@@activeToolID = value
	end

	def self.materialTool
		@@materialTool
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
			Sketchup.active_model.start_operation(traduire('createPocket'), true)
			GNTools::Paths::Pocket.Create(faces,hash)
			Sketchup.active_model.commit_operation
		end


	end
	
	def self.activate_Material
		Sketchup.active_model.tools.push_tool(GNTools::materialTool)
	end
	
	def self.activate_SaveGCode
		GCodeGenerate.SaveAs
	end

	def self.activate_defaultCNCTool
		Sketchup.active_model.select_tool(@@defaultCNCTool)
	end


    def self.activate_GCodeGenerate
       GCodeGenerate.generateGCode2
	end

	def self.create_Menus
	    plugins_menu = UI.menu('Plugins')


		submenu = plugins_menu.add_submenu(traduire("CNC Menu"))
		
		submenu.add_item(traduire('Add Material')) {
			self.activate_Material
		}
		
		submenu.add_item(traduire('Material Default')) {
			self.activate_defaultCNCTool
		}

		submenu.add_item(traduire('DrillBits')) {
			GNTools::DrillBits.show
		}
		submenu.add_item(traduire('GCode Generate')) {
			self.activate_GCodeGenerate
		}

		submenu.add_item(traduire('Save GCode to File')) {
			self.activate_SaveGCode
		}

		
		plugins_menu.add_item(traduire('Construction Line')) {
			self.activate_line_tool
		}
		cmd_circle3x3Tool = UI::Command.new(traduire("Circle From 3 Points")) { Sketchup.active_model.select_tool Circle3X3DPoints.new }
        cmd_circle3x3Tool.tooltip = traduire("Circle passing by 3 points.")
        cmd_circle3x3Tool.status_bar_text = traduire("3 points circle.")
#        cmd_circle3x3Tool.small_icon = File.join(GNTools::PATH_IMAGES, 'Inspector-16.png')
#        cmd_circle3x3Tool.large_icon = File.join(GNTools::PATH_IMAGES, 'Inspector-24.png')
		plugins_menu.add_item(cmd_circle3x3Tool)
		
		
		plugins_menu.add_item(traduire("Reload GNTools")){
			self.reload 
		}

		
	end
	
end
