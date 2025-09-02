module GNTools

	class GN3DToolbars
		def self.load
		#Toolbar definitions
		@toolbar = UI::Toolbar.new "GNTools CNC"
		@toolbar = @toolbar.add_item GNTools::commandClass.cmdCNCTools
		@toolbar = @toolbar.add_item GNTools::commandClass.cmdCreatePath
		@toolbar = @toolbar.add_item GNTools::commandClass.cmdMaterial
		@toolbar = @toolbar.add_item GNTools::commandClass.cmdparamGCode
		@toolbar = @toolbar.add_item GNTools::commandClass.cmdGCode
        @toolbar = @toolbar.add_item GNTools::commandClass.cmdDemoMat
		@toolbar.show
		p "done new toolbar"
		end
	end

end
