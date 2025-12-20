require File.join(GNTools::PATH_ROOT, "GN_command_class.rb")

module GNTools

	class GN3DToolbars

      # getter : accès sans instancier
      def self.toolbar
        @toolbar
      end

	  def self.load
		#Toolbar definitions
		return if @loaded # empêche duplication si déjà chargé

        @toolbar ||= UI::Toolbar.new("GNTools CNC")

		@toolbar = @toolbar.add_item GNTools::commandClass.cmd_Add_Material
		@toolbar = @toolbar.add_item GNTools::commandClass.cmdparamGCode
		@toolbar = @toolbar.add_item GNTools::commandClass.cmd_OctoPrint
		@toolbar = @toolbar.add_item GNTools::commandClass.cmdDrillBits
#		@toolbar = @toolbar.add_item GNTools::commandClass.cmdGCode
#       @toolbar = @toolbar.add_item GNTools::commandClass.cmdDemoMat
#		@toolbar = @toolbar.add_item GNTools::commandClass.cmdCNCNewTools
		@toolbar.show
		@loaded = true
	  end
	  
	  # cacher et reconstruire proprement (utile pour reload)
      def self.reload
        if @toolbar
          @toolbar.hide
          @toolbar = nil
        end
        @loaded = false
        load
      end
	  
	  # debug : itérer sur les commandes
      def self.dump_items
        return unless @toolbar
        @toolbar.each { |item|
          puts item.inspect
        }
      end
	end
end
