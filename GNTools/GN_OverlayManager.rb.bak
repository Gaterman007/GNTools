require 'sketchup.rb'
require "GNTools/Tools/NewPaths/GN_ToolpathPreview.rb"

module GNTools

	OVERLAY_ID   = 'gntools.overlay.main'.freeze
	OVERLAY_NAME = 'GNTools Main Overlay'.freeze

	class ToolpathObserver < Sketchup::Overlay
	  def initialize
		super(OVERLAY_ID, OVERLAY_NAME)
        @hash_collection = nil
		@renderType = "Toolpaths"
      end
	  
	  def set_collection(col)
        @hash_collection = col
        Sketchup.active_model.active_view.invalidate
      end

	  def set_render_type(renderType)
		@renderType = renderType
	  end


	  def getTextBox(point,text,view)
	    bounds = view.text_bounds(point, text, size: 12, bold: true, color: 'white')

		# Compute polygon for the text bounds
		x1, y1 = bounds.upper_left.to_a
		x2, y2 = bounds.lower_right.to_a
		points = [
			Geom::Point3d.new(x1, y1),
			Geom::Point3d.new(x1, y2),
			Geom::Point3d.new(x2, y2),
			Geom::Point3d.new(x2, y1),
		]
	  end

      def draw(view)
		if @hash_collection == nil
			text = "No collection"
			point = Geom::Point3d.new(20, 20, 0)
			box = getTextBox(point,text,view)
			rectangle = [
			  [20, 20, 0], [135, 20, 0], [135, 40, 0], [20, 40, 0]
			]
			view.drawing_color = 'blue'
			view.draw2d(GL_QUADS, box)
#			view.draw2d(GL_QUADS, rectangle)
			view.draw_text(point, "No collection", size: 12, bold: true, color: 'white')
		else
			NewPaths::ToolpathPreview.render(view, @hash_collection,@renderType)
		end
      end
	end

	# ============================================================
	#   2. Singleton Overlay Manager + AppObserver
	# ============================================================
	class OverlayManager < Sketchup::AppObserver
	
	  @@instance = nil
	  def self.instance
		@@instance ||= new
	  end

	  attr_accessor :model_overlay

	  private_class_method :new

	  def initialize
		Sketchup.add_observer(self)
		self.register_overlay(Sketchup.active_model,ToolpathObserver)
	  end

	  def onExtensionsLoaded
	    puts "onExtensionsLoaded"
		# quand tout les extension son loader
	  end

	  def onNewModel(model)
		self.register_overlay(Sketchup.active_model,ToolpathObserver)
	  end

	  def onOpenModel(model)
		self.register_overlay(Sketchup.active_model,ToolpathObserver)
	  end

	  def onQuit()
	    puts "onQuit"
	  end

	  def onUnloadExtension(extension_name)
	    puts "onUnloadExtension: #{extension_name}"
		# l extention est soit pas loader ou doit etre unloader
	  end

	  # Ajouter un overlay à un modèle
	  def register_overlay(model, overlay_class)
		@model_overlay = overlay_class.new
		model.overlays.add(@model_overlay)
	  end

	  def self.set_collection(collection)
		@@instance.model_overlay.set_collection(collection)
	  end

	  def self.set_render_type(renderType)
		@@instance.model_overlay.set_render_type(renderType)
	  end

	  # Activer/désactiver overlay
	  def set_overlay(id, state)
		overlay = Sketchup.active_model.overlays.find { |ov| ov.overlay_id == id }
		overlay.enabled = state if overlay
	  end

	  # Supprimer overlay
	  def remove_overlay(id)
		overlay = Sketchup.active_model.overlays.find { |ov| ov.overlay_id == id }
		Sketchup.active_model.overlays.remove(overlay) if overlay
	  end
	  
	end
	
    # ============================================================
    #   3. Appel initial
    # ============================================================
	manager = OverlayManager.instance
	manager.set_overlay(OVERLAY_ID, true)
end