module GNTools

	class GN3DToolbars
		def self.load
		#Toolbar definitions
		@toolbar = UI::Toolbar.new "GNTools CNC"
		@cmd = UI::Command.new("AddPath") {GNTools::activate_CreateTool}
		@cmd.small_icon = File.join(GNTools::PATH_IMAGES,"HoleSmallPlus.png")
		@cmd.large_icon = File.join(GNTools::PATH_IMAGES,"HoleLargePlus.png")
		@cmd.tooltip = "CNC Add"
		@cmd.status_bar_text = "CNC Add"
		@cmd.menu_text = "CNC Add"
		@cmd.set_validation_proc {
#			puts GNTools::ObserverModule.allEdges
		  GNTools::ObserverModule.hasCircle = false
		  GNTools.verifieSelection(Sketchup.active_model.selection)
		  if Sketchup.active_model.selection.length != 0 && (GNTools::ObserverModule.hasCircle || GNTools::ObserverModule.hasEdges|| GNTools::ObserverModule.hasFaces)
			MF_ENABLED
		  else
			MF_GRAYED
		  end
		}
#		MF_ENABLED, MF_DISABLED, MF_CHECKED, MF_UNCHECKED, or MF_GRAYED
		@toolbar = @toolbar.add_item @cmd

		@cmd = UI::Command.new("CreatePath") {GNTools::activate_PathTool}
		@cmd.small_icon = File.join(GNTools::PATH_IMAGES,"HoleSmall.png")
		@cmd.large_icon = File.join(GNTools::PATH_IMAGES,"HoleLarge.png")
		@cmd.tooltip = "CNC Tool"
		@cmd.status_bar_text = "CNC Tool"
		@cmd.menu_text = "CNC Tool"
		@cmd.set_validation_proc {
#			puts GNTools::ObserverModule.allEdges
		  if Sketchup.active_model.selection.length != 0 && GNTools::ObserverModule.allEdges
			MF_GRAYED
		  else
			MF_ENABLED
		  end
		}
#		MF_ENABLED, MF_DISABLED, MF_CHECKED, MF_UNCHECKED, or MF_GRAYED
		@toolbar = @toolbar.add_item @cmd

		

		
		paramGCode = UI::Command.new("GCode") {GNTools::activate_defaultCNCTool}
		paramGCode.small_icon = File.join(GNTools::PATH_IMAGES,"MaterialParamSmall.png")
		paramGCode.large_icon = File.join(GNTools::PATH_IMAGES,"MaterialParam.png")
		paramGCode.tooltip = "Parameters GCode"
		paramGCode.status_bar_text = "Parameters GCode"
		paramGCode.menu_text = "Parameters GCode"
		@toolbar = @toolbar.add_item paramGCode


		cmdMaterial = UI::Command.new("Material") {GNTools::activate_Material}
		cmdMaterial.small_icon = File.join(GNTools::PATH_IMAGES,"PlayCncLarge.png")
		cmdMaterial.large_icon = File.join(GNTools::PATH_IMAGES,"PlayCncSmall.png")
		cmdMaterial.tooltip = "Add Material"
		cmdMaterial.status_bar_text = "Add Material"
		cmdMaterial.menu_text = "Add Material"
		@toolbar = @toolbar.add_item cmdMaterial

		cmdGCode = UI::Command.new("GCode") {GNTools::activate_SaveGCode}
		cmdGCode.small_icon = File.join(GNTools::PATH_IMAGES,"GcodeSmall.png")
		cmdGCode.large_icon = File.join(GNTools::PATH_IMAGES,"GcodeLarge.png")
		cmdGCode.tooltip = "Generate GCode"
		cmdGCode.status_bar_text = "Generate GCode"
		cmdGCode.menu_text = "Generate GCode"
		@toolbar = @toolbar.add_item cmdGCode


		
		@toolbar.show
		p "done new toolbar"
		end
	end

end