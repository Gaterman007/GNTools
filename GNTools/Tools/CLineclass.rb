require 'sketchup.rb'

module GNTools
  
  class LineTool
 
    # Threshold in logical screen pixels for when the mouse is considered to
    # be dragged.
    DRAG_THRESHOLD = 10
    @@cursorNumber = 415
    
    def activate

      @mouse_ip = Sketchup::InputPoint.new
      @picked_first_ip = Sketchup::InputPoint.new
      @dragged = false
      @mouseButton = false
      @mouse_pos_down = ORIGIN
      @state = 0
      
      update_ui
    end

    def deactivate(view)
      view.invalidate
    end

    def resume(view)
      update_ui
      view.invalidate
    end

    def suspend(view)
      view.invalidate
    end

    def onCancel(reason, view)
      reset_tool
      view.invalidate
    end

    def onLButtonDown(flags, x, y, view)
      @mouseButton = true
      # Track where in screen space mouse is pressed down.
      @mouse_down = Geom::Point3d.new(x, y)
      @@cursorNumber = @@cursorNumber + 1
      GNTools::fixCursorDisplay
      if @state == 0
        @picked_first_ip.pick(view, x, y)
        @state = 1
      else 
        if @state == 1
          @mouse_ip.pick(view, x, y, @picked_first_ip)
          @state = 2
        end
      end
      update_ui
      view.invalidate
    end

    def onMouseMove(flags, x, y, view)
      if @mouseButton
        if (!@dragged) && (@mouse_down.distance([x, y]) > DRAG_THRESHOLD)
          @dragged = true
        end
      end
      if picked_first_point?
        @mouse_ip.pick(view, x, y, @picked_first_ip)
      else
        @mouse_ip.pick(view, x, y)
      end
      
      view.tooltip = @mouse_ip.tooltip if @mouse_ip.valid?
      view.invalidate
      update_ui
    end

    def onLButtonUp(flags, x, y, view)
#     if picked_first_point? && @dragged = false
#       @picked_first_ip.copy!(@mouse_ipif , y, view)
#     end
		if @state == 2
			create_edge
			@picked_first_ip.clear
			@state = 0
		end
		if @state == 1
			if @dragged
				create_edge
				@picked_first_ip.clear
				@state = 0
			end
		end
		@mouseButton = false
		@dragged = false
		update_ui
		view.invalidate
    end

    CURSOR_PENCIL = 635
    def onSetCursor
      UI.set_cursor(@@cursorNumber)
    end

    def draw(view)
      draw_preview(view)
      @mouse_ip.draw(view) if @mouse_ip.display?
    end

    def getExtents
      bounds = Geom::BoundingBox.new
      points = picked_points
      return unless points.size == 2
      bounds.add(picked_points)
      bounds
    end

    private

    def update_ui
      if picked_first_point?
        Sketchup.status_text = @@cursorNumber
      else
        Sketchup.status_text = @@cursorNumber
      end
    end

    def reset_tool
      @picked_first_ip.clear
      @mouse_ip.clear
      @state = 0
      @dragged = false
      @mouseButton = false
      @mouse_pos_down = ORIGIN
      update_ui
    end

    def picked_first_point?
      @picked_first_ip.valid?
    end

    def picked_points
      points = []
      points << @picked_first_ip.position if picked_first_point?
      points << @mouse_ip.position if @mouse_ip.valid?
      points
    end

    def draw_preview(view)
      points = picked_points
      return unless points.size == 2
      view.set_color_from_line(*points)
      view.line_width = 1
#      view.line_stipple = '-'
      view.line_stipple = '_'      
      view.draw(GL_LINES, points)
    end

    def create_edge
      model = Sketchup.active_model
      model.start_operation('Edge', true)
      len_points = picked_points.length
      edge = model.active_entities.add_cpoint(picked_points[len_points - 1])
      edge = model.active_entities.add_cline(picked_points[len_points - 1],picked_points[len_points - 2])
#       num_faces = edge.find_faces || 0 # API returns nil instead of 0.
      model.commit_operation
#       num_faces
    end

  end # class LineTool


end # GNTools
