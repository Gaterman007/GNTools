#-----------------------------------------------------------------------------
# Copyright 2022, Gaetan Noiseux,
#  load "C:/Users/Gaetan/Documents/Sketchup/GN3DPrinterCNC.rb"
# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#-----------------------------------------------------------------------------
require 'sketchup.rb'
require File.join(GNTools::PATH_TOOLS, "GN_ToolPath.rb")
require File.join(GNTools::PATH_TOOLS, "GN_materialTool.rb")
require File.join(GNTools::PATH_TOOLS, "GN_OctoPrintDialog.rb")
require File.join(GNTools::PATH_TOOLS, "octoPrint.rb")

module GNTools


	class CommandClass
	
		attr_accessor :cmd_circle3x3Tool
		attr_accessor :cmd_Add_Material
		attr_accessor :cmdparamGCode
		attr_accessor :cmdGCode
        attr_accessor :cmdDemoMat
		attr_accessor :cmdSaveGCode
		attr_accessor :cmdDrillBits
		attr_accessor :cmdConstructionLine
		attr_accessor :cmdCNCNewTools
		attr_accessor :cmd_OctoPrint
		attr_accessor :cmd_configToolpaths
		
		def initialize
			@cmd_circle3x3Tool = UI::Command.new(GNTools.traduire("Circle From 3 Points")) { Sketchup.active_model.select_tool Circle3X3DPoints.new }
			@cmd_circle3x3Tool.tooltip = GNTools.traduire("Circle passing by 3 points.")
			@cmd_circle3x3Tool.status_bar_text = GNTools.traduire("3 points circle.")
#        		@cmd_circle3x3Tool.small_icon = File.join(GNTools::PATH_IMAGES, 'Inspector-16.png')
#        		@cmd_circle3x3Tool.large_icon = File.join(GNTools::PATH_IMAGES, 'Inspector-24.png')
			@cmd_circle3x3Tool.menu_text = GNTools.traduire("Circle From 3 Points")
			
			#---------------------------------
			# Command Menu addition de material
			#---------------------------------
			@cmd_Add_Material = UI::Command.new(GNTools.traduire('Add Material')) {
				@dialogMaterial = GNTools::activate_Material
			}

			@cmd_Add_Material.set_validation_proc {
				model = Sketchup.active_model
				selection = model.selection
				groups = selection.grep(Sketchup::Group)
				
				if groups.count == 1 
					if GNTools::Material.cnc?(groups[0]) || groups[0].manifold?
						MF_ENABLED
					else
						MF_GRAYED
					end
				else
					MF_GRAYED
				end
			}
			#		MF_ENABLED, MF_DISABLED, MF_CHECKED, MF_UNCHECKED, or MF_GRAYED
#			@cmdMaterial = UI::Command.new("Material") {GNTools::activate_Material}
			@cmd_Add_Material.small_icon = File.join(GNTools::PATH_IMAGES,"MaterielSmall.png")
			@cmd_Add_Material.large_icon = File.join(GNTools::PATH_IMAGES,"MaterielLarge.png")
			@cmd_Add_Material.tooltip = "Add Material"
			@cmd_Add_Material.status_bar_text = "Add Material"
			@cmd_Add_Material.menu_text = "Add Material"
			

			@cmd_OctoPrint = UI::Command.new("OctoPrint") {GNTools::activate_OctoPrint}
			@cmd_OctoPrint.small_icon = File.join(GNTools::PATH_IMAGES,"Print3DSmall.png")
			@cmd_OctoPrint.large_icon = File.join(GNTools::PATH_IMAGES,"Print3DLarge.png")			
			@cmd_OctoPrint.tooltip = "OctoPrint Menu"
			@cmd_OctoPrint.status_bar_text = "OctoPrint Menu"
			
#			@cmdCNCTools = UI::Command.new("AddPath") {GNTools::activate_CreateTool}
#			@cmdCNCTools.small_icon = File.join(GNTools::PATH_IMAGES,"HoleSmallPlus.png")
#			@cmdCNCTools.large_icon = File.join(GNTools::PATH_IMAGES,"HoleLargePlus.png")
#			@cmdCNCTools.tooltip = "Add tool Path"
#			@cmdCNCTools.status_bar_text = "Add tool Path"
#			@cmdCNCTools.menu_text = "Add tool Path"
#			@cmdCNCTools.set_validation_proc {
#			  GNTools::ObserverModule.hasCircle = false
#			  GNTools.verifieSelection(Sketchup.active_model.selection)
##			  if GNTools.materialList.count != 0
#				  if Sketchup.active_model.selection.length != 0 && (GNTools::ObserverModule.hasCircle || GNTools::ObserverModule.hasEdges|| GNTools::ObserverModule.hasFaces)
#					MF_ENABLED
#				  else
#					MF_GRAYED
#				  end
##			  else
#				MF_GRAYED
#			  end
#			}
			
			@cmdCNCNewTools = UI::Command.new("AddNewPath") {GNTools::activate_callTools}
			@cmdCNCNewTools.small_icon = File.join(GNTools::PATH_IMAGES,"NewToolPathSmall.png")
			@cmdCNCNewTools.large_icon = File.join(GNTools::PATH_IMAGES,"NewToolPathLarge.png")
			@cmdCNCNewTools.tooltip = "Add new tool Path"
			@cmdCNCNewTools.status_bar_text = "Add new tool Path"
			@cmdCNCNewTools.menu_text = "Add new tool Path"
			

			@cmd_configToolpaths = UI::Command.new("ConfigurePath") {GNTools::configure_ToolPath}
			@cmd_configToolpaths.tooltip = "Configure Tool Path"
			@cmd_configToolpaths.status_bar_text = "Configure Tool Path"
			@cmd_configToolpaths.menu_text = "Configure Tool Path"

			
#			@cmdCreatePath = UI::Command.new("CreatePath") {GNTools::activate_PathTool}
#			@cmdCreatePath.small_icon = File.join(GNTools::PATH_IMAGES,"HoleSmall.png")
#			@cmdCreatePath.large_icon = File.join(GNTools::PATH_IMAGES,"HoleLarge.png")
#			@cmdCreatePath.tooltip = "CNC Tool Path"
#			@cmdCreatePath.status_bar_text = "CNC Tool Path"
#			@cmdCreatePath.menu_text = "CNC Tool Path"
#			@cmdCreatePath.set_validation_proc {
#			  if GNTools.materialList.count != 0
#				if Sketchup.active_model.selection.length == 0 # && GNTools::ObserverModule.allEdges
#					MF_GRAYED
#				else
#					MF_ENABLED
#				end
#			  else
#				MF_GRAYED
#			  end
#			}


			@cmdparamGCode = UI::Command.new("GCode") {Sketchup.active_model.select_tool(GNTools.defaultCNCTool)}
			@cmdparamGCode.small_icon = File.join(GNTools::PATH_IMAGES,"ConfigSmall.png")
			@cmdparamGCode.large_icon = File.join(GNTools::PATH_IMAGES,"ConfigLarge.png")
			@cmdparamGCode.tooltip = "Parameters GCode"
			@cmdparamGCode.status_bar_text = "Parameters GCode"
			@cmdparamGCode.menu_text = "Parameters GCode"



			@cmdGCode = UI::Command.new("GCode") {GCodeGenerate.SaveAs}
			@cmdGCode.small_icon = File.join(GNTools::PATH_IMAGES,"GcodeSmall.png")
			@cmdGCode.large_icon = File.join(GNTools::PATH_IMAGES,"GcodeLarge.png")
			@cmdGCode.tooltip = "Generate GCode"
			@cmdGCode.status_bar_text = "Generate GCode"
			@cmdGCode.menu_text = "Generate GCode"


        
			@cmdDemoMat = UI::Command.new("DemoMateriel") {
					Sketchup.active_model.select_tool(GNTools.defaultCNCTool)
			}
			@cmdDemoMat.small_icon = File.join(GNTools::PATH_IMAGES,"DemoMaterielSmall.png")
			@cmdDemoMat.large_icon = File.join(GNTools::PATH_IMAGES,"DemoMaterielLarge.png")
			@cmdDemoMat.tooltip = GNTools.traduire("Generate Demo")
			@cmdDemoMat.status_bar_text = GNTools.traduire("Generate Demo")
			@cmdDemoMat.menu_text = GNTools.traduire("Generate Demo")

			@cmdSaveGCode = UI::Command.new("DemoMateriel") { self.activate_SaveGCode }
			@cmdSaveGCode.tooltip = GNTools.traduire('Save GCode to File')
			@cmdSaveGCode.status_bar_text = GNTools.traduire('Save GCode to File')
			@cmdSaveGCode.menu_text = GNTools.traduire('Save GCode to File')
			
			
			@cmdDrillBits = UI::Command.new("DrillBits")  { GNTools::DrillBits.show }
			@cmdDrillBits.tooltip = GNTools.traduire('DrillBits')
			@cmdDrillBits.status_bar_text = GNTools.traduire('DrillBits')
			@cmdDrillBits.menu_text = GNTools.traduire('DrillBits')
			@cmdDrillBits.small_icon = File.join(GNTools::PATH_IMAGES,"DrillBitsSmall.png")
			@cmdDrillBits.large_icon = File.join(GNTools::PATH_IMAGES,"DrillBitsLarge.png")

			@cmdConstructionLine = UI::Command.new("Construction_Line")  { Sketchup.active_model.select_tool(LineTool.new) }
			@cmdConstructionLine.tooltip = GNTools.traduire('Construction Line')
			@cmdConstructionLine.status_bar_text = GNTools.traduire('Construction Line')
			@cmdConstructionLine.menu_text = GNTools.traduire('Construction Line')

		end	# initialize
	end		# class

	def self.octoPrint
		@@octoPrint
	end

	def self.commandClass
		@@commandClass
	end

	def self.defaultCNCTool
		@@defaultCNCTool
	end

	def self.configure_ToolPath
	  GNTools::ToolpathConfigDialog.instance.show_dialog
	end

	def self.activeToolID
		@@activeToolID
	end

	def self.activeToolID=(value)
		@@activeToolID = value
	end
	
	def self.activate_OctoPrint
		@@octoPrintDiag ||= GNTools::OctoPrintDialog.new
        @@octoPrintDiag.show_dialog
	end
	
	def self.activate_Material
		GNTools::MaterialTool.tool_instance ||= GNTools::MaterialTool.new
	    current = Sketchup.active_model.tools.active_tool
	    instance = GNTools::MaterialTool.tool_instance
	    if current.is_a?(GNTools::MaterialTool)
		  GNTools::MaterialTool.tool_instance.dialog.bring_to_front
	    else
		  Sketchup.active_model.select_tool(instance)
	    end
	    nil
	end

    def self.activate_GCodeGenerate
       GCodeGenerate.generatePreview
	end
	
	def self.activate_callTools
	  # Garantit que l'instance existe
	  GNTools::NewPaths::ToolPathDialog.tool_instance ||= GNTools::NewPaths::ToolPathDialog.new
	  # si le tool actif est deja la bring_to_front sinon selectionne le toolinstance
	  current = Sketchup.active_model.tools.active_tool
	  instance = GNTools::NewPaths::ToolPathDialog.tool_instance
	#  instance.set_collection($col)
	  if current.is_a?(GNTools::NewPaths::ToolPathDialog)
		GNTools::NewPaths::ToolPathDialog.tool_instance.dialog.bring_to_front
	  else
		Sketchup.active_model.select_tool(instance)
	  end
	  nil
	end
	
end
