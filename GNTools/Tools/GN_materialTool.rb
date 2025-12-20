require 'sketchup.rb'
require 'json'
require_relative "GN_Material"

module GNTools

    module MaterialToolModeManager

      def set_state(new_state)
		# :idle :first_point_selected :second_point_selected :arc_third_point
        @state = new_state
        Sketchup.active_model.active_view.invalidate if defined?(Sketchup)
      end

      def setInputMode(new_mode)
        valid_modes = [:point, :line, :arc, :loop, :multiline]
        unless valid_modes.include?(new_mode)
          return
        end

        @input_mode = new_mode
        # reset input points
        @ip1 = Sketchup::InputPoint.new
        @ip2 = Sketchup::InputPoint.new
        @ip3 = Sketchup::InputPoint.new
        @state = :idle
        @points.clear if defined?(@points) && [:multiline, :loop].include?(new_mode)

        Sketchup.active_model.active_view.invalidate if defined?(Sketchup)
      end

      def setModeFromtoolpath_type
        return unless @schemas_hash && @toolpath_type_setting
        new_mode_str = @schemas_hash[@toolpath_type_setting]["Strategy"]["Selection"] rescue nil
        mode_map = { "Point" => :point, "Line" => :line, "Arc" => :arc, "Multiline" => :multiline, "Loop" => :loop }
        new_mode = mode_map[new_mode_str]
        if new_mode
          setInputMode(new_mode)
        else
          puts "[ToolPathDialog] Strategy unknown: #{new_mode_str}"
        end
      end
    end

    module MaterialToolMouseEvents

      def onLButtonDown(flags, x, y, view)
        return unless @active
        ip = Sketchup::InputPoint.new
        ip.pick(view, x, y)
        @dragging = false

        case @input_mode
        when :point
          @ip1.copy!(ip)
          set_state(:first_point_selected) if @state == :idle
        when :line
          if @state == :idle
            @ip1.copy!(ip)
            @ip2.copy!(Sketchup::InputPoint.new)
            set_state(:first_point_selected)
          else
            @ip2.copy!(ip)
            set_state(:second_point_selected)
          end
        when :multiline, :loop
          if @state == :idle
            @points = []
            @ip1.copy!(ip)
            @ip2.copy!(Sketchup::InputPoint.new)
            set_state(:first_point_selected)
          elsif @state == :first_point_selected
            @ip2.copy!(ip)
            set_state(:second_point_selected)
          end
        when :arc
          if @state == :idle		
            @ip1.copy!(ip)
			@ip2.copy!(Sketchup::InputPoint.new)
			@ip3.copy!(Sketchup::InputPoint.new)
			puts "first point down"
            set_state(:first_point_selected)  # pass au 1 point correct
          elsif @state == :first_point_selected	
            @ip2.copy!(ip)
			puts "second point down"
            set_state(:second_point_selected)      # pass au 2 eme point
          elsif @state == :second_point_selected 
            @ip3.copy!(ip)
			puts "third point down"
            set_state(:arc_third_point)       # pass au 3 eme point
          end
        end
        view.invalidate
      end

      def onMouseMove(flags, x, y, view)
        return unless @active
        return if @state == :idle

        @dragging = true if flags & MK_LBUTTON != 0

        # Try snapping to existing temporary lines if present
        closest = snap_to_lines(x, y, view)
        if closest
          # if snap found, copy closest into @ip2 as a temporary InputPoint
		  if @input_mode == :arc
			if @state == :first_point_selected
			  if @dragging or not (flags & MK_LBUTTON != 0)
			    @ip2.copy!(Sketchup::InputPoint.new)
			    @ip2.pick(view, x, y, @ip1)
			  else
			    @ip1.copy!(Sketchup::InputPoint.new)
			    @ip1.pick(view, x, y)
			  end
		    elsif @state == :second_point_selected
			  @ip2.copy!(Sketchup::InputPoint.new)
			  @ip2.pick(view, x, y, @ip1)
		    elsif @state == :arc_third_point
			  @ip3.copy!(Sketchup::InputPoint.new)
			  # We cannot directly copy a Geom::Point3d into an InputPoint, so pick near the mouse
			  @ip3.pick(view, x, y, @ip1)
			  # override position by using linear combination trick via temporary entity is heavy
			  # For now we just keep closest for logic and continue showing preview
		    end
		  else
			ip = Sketchup::InputPoint.new
            ip.pick(view, x, y, @ip1)
            @ip2.copy!(ip)			
		  end
          @snapped_position = closest
        else
          @snapped_position = nil
          ip = Sketchup::InputPoint.new
		  if @input_mode == :arc
			if @state == :first_point_selected
			  if @dragging
			    @ip2.copy!(Sketchup::InputPoint.new)
			    @ip2.pick(view, x, y, @ip1)
			  else
			    @ip1.copy!(Sketchup::InputPoint.new)
			    @ip1.pick(view, x, y)
			  end
		    elsif @state == :second_point_selected
			  @ip2.copy!(Sketchup::InputPoint.new)
			  @ip2.pick(view, x, y, @ip1)
		    elsif @state == :arc_third_point
			  @ip3.copy!(Sketchup::InputPoint.new)
			  # We cannot directly copy a Geom::Point3d into an InputPoint, so pick near the mouse
			  @ip3.pick(view, x, y, @ip1)
			  # override position by using linear combination trick via temporary entity is heavy
			  # For now we just keep closest for logic and continue showing preview
		    end
		  else
            ip.pick(view, x, y, @ip1)
            @ip2.copy!(ip)
		  end

          if @input_mode == :point
            ip.pick(view, x, y)
            @ip1.copy!(ip)
          end
        end

        view.invalidate
      end

      def onLButtonUp(flags, x, y, view)
        return unless @active
        return if @state == :idle
        ip = Sketchup::InputPoint.new
        case @input_mode
        when :point
          ip.pick(view, x, y, @ip1)
          @ip2.copy!(ip)
          add_point(@ip2.position)
          set_state(:idle)
		  @points.clear
        when :line
          ip.pick(view, x, y, @ip1)
          @ip2.copy!(ip)
          if @dragging
            add_segment(@ip1.position, @ip2.position)
            set_state(:idle)
			@points.clear
          else
            if @state == :first_point_selected
              # treat as selection of first point, keep waiting
              set_state(:second_point_selected)
            elsif @state == :second_point_selected
              add_segment(@ip1.position, @ip2.position)
              set_state(:idle)
            else
              set_state(:idle)
            end
			@points.clear
          end
        when :multiline, :loop
          ip.pick(view, x, y, @ip1)
          @ip2.copy!(ip)
          if @dragging || @state == :second_point_selected
            @points << @ip1.position
            @points << @ip2.position
          end
          @ip1.copy!(@ip2)

          if @input_mode == :loop
            if !@points.empty? && (@points.first - @ip2.position).length < 1.mm
              # close loop
              finalize_loop(@points)
              set_state(:idle)
			  @points.clear
            else
              set_state(:second_point_selected)
            end
          else
            set_state(:second_point_selected)
          end
        when :arc
          case @state
          when :first_point_selected
			puts "first point up"
			if @dragging
			  ip.pick(view, x, y, @ip1)
			  @ip2.copy!(ip)
			  set_state(:arc_third_point)  # pass au 3 point correct
			else
			  ip.pick(view, x, y)
              @ip1.copy!(ip)
			  set_state(:first_point_selected) # pass au 2 point quand on va faire down
			end
          when :second_point_selected
#			midpoint = ToolPathDialogDraw::midpoint_of_3Dpoints(@ip1.position, @ip2.position)
#			puts "midpoint"
#			puts midpoint.position
#			screen_point = view.screen_coords(midpoint.position)
			# avec view on change midpoint.position pour x,y cursorpos
#			Win32API2::CursorPos.setcursorpos(screen_point.x,screen_point.y)
#			@ip3.pick(view, screen_point.x, screen_point.y)
			puts "second point up"
			ip.pick(view, x, y, @ip1)
            @ip2.copy!(ip)
            set_state(:arc_third_point)
		  when :arc_third_point		  
			puts "third point up"
		    # finalize arc on down (alternate behavior)
			ip.pick(view, x, y, @ip2)
            @ip3.copy!(ip)
            add_arc(@ip1.position, @ip2.position, @ip3.position)
            set_state(:idle)
			@points.clear
          end
        end

        @dragging = false
        view.invalidate
      end

      # helper for snapping: returns Geom::Point3d or nil
      def snap_to_lines(x, y, view)
        return nil unless @points && @points.length >= 2
        min_dist = Float::INFINITY
        closest = nil
        ip = view.inputpoint(x, y)
        mouse_pos = ip.position

        @points.each_cons(2) do |p1, p2|
          screen1 = view.screen_coords(p1)
          screen2 = view.screen_coords(p2)

          dx = screen2.x - screen1.x
          dy = screen2.y - screen1.y
          denom = dx*dx + dy*dy
          next if denom == 0

          t = ((x - screen1.x) * dx + (y - screen1.y) * dy) / denom
          t = [[t, 0].max, 1].min
          proj = Geom::Point3d.linear_combination(1-t, p1, t, p2)
          dist = (proj - mouse_pos).length

          if dist < min_dist
            min_dist = dist
            closest = proj
          end
        end
        closest
      end

      def onKeyDown(key, repeat, flags, view)
        case key
        when 0x1B, 0x0D  # ESC ou Enter
          if [:multiline, :loop].include?(@input_mode) && !@points.empty?
            if key == 0x1B
              puts "Annulé la ligne en cours"
            else
			  finalize_loop(@points)
            end
            @points = []
            @ip1.copy!(Sketchup::InputPoint.new)
            @ip2.copy!(Sketchup::InputPoint.new)
            set_state(:idle)
            view.invalidate
          end
        end
      end

    end

    module MaterialToolDraw
	
      def midpoint_of_3Dpoints(p1, p2)
        #determine the midpoint of p1 and p2
        midpoint_p1_p2 = Geom::Point3d.new
        if p1.x < p2.x
          midpoint_p1_p2.x = p1.x + (p1.x - p2.x).abs/2
        else
          midpoint_p1_p2.x = p2.x + (p1.x - p2.x).abs/2
        end
        if p1.y < p2.y
          midpoint_p1_p2.y = p1.y + (p1.y - p2.y).abs/2
        else
          midpoint_p1_p2.y = p2.y + (p1.y - p2.y).abs/2
        end
        if p1.z < p2.z
          midpoint_p1_p2.z = p1.z + (p1.z - p2.z).abs/2
        else
          midpoint_p1_p2.z = p2.z + (p1.z - p2.z).abs/2
        end
		midpoint_p1_p2	
      end #of midpoint_of_3Dpoints(p1, p2)
	
      def circleCenterVectorAndRadius(pt1, pt2, pt3)
        # Draw a circle on the plane determined by the 3 points with circumference located on the 3 input points.
        #1st determine the midpoint of pt1 and pt2
        midpoint_of_3Dpoints_p1_p2 = midpoint_of_3Dpoints(pt1, pt2)
        #2nd determine the midpoint of pt2 and pt3
        midpoint_of_3Dpoints_p2_p3 = midpoint_of_3Dpoints(pt2, pt3)
      #determin the perpendicular bisector of points p1 and p2 on plane defined by points p1,p2 and p3
        vector_from_line_p1_p2 = Geom::Vector3d.new pt1.x - pt2.x, pt1.y - pt2.y, pt1.z - pt2.z
        vector_from_line_p2_p3 = Geom::Vector3d.new pt2.x - pt3.x, pt2.y - pt3.y, pt2.z - pt3.z
        vector_verticle = vector_from_line_p1_p2.cross vector_from_line_p2_p3
        rotate_90_degrees_transform = Geom::Transformation.rotation midpoint_of_3Dpoints_p1_p2, vector_verticle , Math::PI/2 #90degrees
        vector_perpendicular_to_line_p1_p2 = Geom::Vector3d.new vector_from_line_p1_p2
        vector_perpendicular_to_line_p1_p2.transform! rotate_90_degrees_transform
        vector_perpendicular_to_line_p2_p3 = Geom::Vector3d.new vector_from_line_p2_p3
        vector_perpendicular_to_line_p2_p3.transform! rotate_90_degrees_transform
        centre_point = Geom.intersect_line_line [midpoint_of_3Dpoints_p1_p2,vector_perpendicular_to_line_p1_p2], [midpoint_of_3Dpoints_p2_p3,vector_perpendicular_to_line_p2_p3]
		if centre_point.nil?
		  puts "Impossible de calculer le centre : les points sont probablement alignés."
		  puts pt1,pt2,pt3
		  return nil
		end
        radius = pt1.distance centre_point
        centerVectorAndRadius = [centre_point,vector_verticle,radius]  #center of circle, the plane of circle, radius
        centerVectorAndRadius
      end	
	
      def draw(view)
        return unless @active
        return if @state == :idle

        view.drawing_color = "red"
        view.line_width = 2

        case @input_mode
        when :point
          @ip1.draw(view) if @ip1.valid?
        when :line
          if @ip1.valid? && @ip2.valid?
            view.draw_line(@ip1.position, @ip2.position)
          end
          @ip1.draw(view) if @ip1.valid?
          @ip2.draw(view) if @ip2.valid?
        when :multiline, :loop
          @points.each_cons(2) { |p1, p2| view.draw_line(p1, p2) }
          if @ip1.valid? && @ip2.valid?
            view.draw_line(@ip1.position, @ip2.position)
          end
          @ip1.draw(view) if @ip1.valid?
          @ip2.draw(view) if @ip2.valid?
        when :arc
		  if @ip1.valid? && @ip2.valid? && @ip3.valid?
#			center, normal, radius = circleCenterVectorAndRadius(@ip1.position, @ip2.position, @ip3.position)

			# vecteurs relatifs pour calculer les angles
#			v1 = @ip1.position - center
#			v2 = @ip2.position - center
#			v3 = @ip3.position - center

			# on projette v1 et v3 sur le plan
#			x_axis = v1.normalize
#			y_axis = normal * x_axis

			# angles de départ et d'arrivée
#			angle1 = 0
#			angle3 = Math.atan2((v3.dot(y_axis)), (v3.dot(x_axis)))

#			segments = 12
#			arc_points = []
#			puts "arc = "
#			puts center
#			puts radius
#			segments.times do |i|
#			  t = i.to_f / (segments - 1)
#			  angle = angle1 + t * (angle3 - angle1)
#			  puts angle
#			  puts x_axis
#			  puts Math.cos(angle)
#			  puts y_axis
#			  puts x_axis.clone * Math.cos(angle)
#			  puts y_axis.clone * Math.sin(angle)
#			  puts x_axis.clone * Math.cos(angle) * radius
#			  puts y_axis.clone * Math.sin(angle) * radius
#			  point = center + x_axis.clone * Math.cos(angle) * radius + y_axis.clone * Math.sin(angle) * radius
#			  arc_points << point
#			end
#
#			arc_points.each_cons(2) { |p1, p2| view.draw_line(p1, p2) }
		  elsif @ip1.valid? && @ip2.valid?
			view.draw_line(@ip1.position, @ip2.position)
		  end
		
          @ip1.draw(view) if @ip1.valid?
          @ip2.draw(view) if @ip2.valid?
          @ip3.draw(view) if @ip3.valid?
        end
      end
    end

	module MaterialToolDialogManager

	  def accept_Pressed(value,matvalue)
		puts "Ok press"
		apply_Pressed(value,matvalue)
		close_dialog
		Sketchup.active_model.tools.pop_tool
		nil
	  end

	  def cancel_Pressed(value)
		puts "Cancel press"
		if @undoRedoName == GNTools::OperationTracker.current_op and @undoRedoDepth == GNTools::OperationTracker.stack_depth
		  Sketchup.active_model.abort_operation()
		end
		close_dialog
		Sketchup.active_model.tools.pop_tool
		nil
	  end

	  def setDefault_Pressed(value)
		puts "Set Default press"
	    nil
	  end
	  
	  def apply_Pressed(value,matvalue)
		puts "Apply values #{value} #{matvalue}"
		# Mettre à jour les données temporaires
		# Écrire directement dans le groupe via Material
		@material["toolpaths"] = value
		@material.update do |d|
		  d["material_type"] = matvalue["material_type"]
		  d["safeHeight"] = matvalue["safeHeight"]
		  d["materialHeight"] = matvalue["materialHeight"]
		end
		if @undoRedoName == GNTools::OperationTracker.current_op and @undoRedoDepth == GNTools::OperationTracker.stack_depth
		  Sketchup.active_model.commit_operation()
		end
	    nil
	  end
	  
	  def show_dialog
		if @dialog && @dialog.visible?
		  self.update_dialog
		  @dialog.bring_to_front
		else
		  # Attach content and callbacks when showing the dialog,
		  # not when creating it, to be able to use the same dialog again.
		  # on a 4 bouton   $( "#accept, #cancel, #setDefault, #apply").button();
		  # sketchup.apply();   			bouton Apply
		  # sketchup.accept();  			bouton Ok
		  # sketchup.setDefault(defaults);	bouton set Default
		  # sketchup.cancel();				bouton Cancel
		  
		  @dialog ||= self.create_dialog
		  @dialog.add_action_callback("ready") { |action_context|
			dialog_opened
			nil
		  }
		  # set to model only
		  @dialog.add_action_callback("accept") { |action_context, value, matvalue|
			accept_Pressed(value,matvalue)
		  }
		  @dialog.add_action_callback("cancel") { |action_context, value|
			cancel_Pressed(value)
		  }
		  @dialog.add_action_callback("setDefault") { |action_context, value|
			setDefault_Pressed(value)
		  }
		  @dialog.add_action_callback("apply") { |action_context, value, matvalue|
			apply_Pressed(value,matvalue)
		  }
	  
		  @dialog.add_action_callback("applyViewMode") { |action_context, mode|
			self.applyViewMode(mode)
			nil
		  }
		  bind_dialog_callbacks
		  @dialog.set_size(@dialog_width,@dialog_height)
		  @dialog.set_on_closed { on_dialog_closed }
          screen_width, screen_height, dpi = Win32API2::User32.screen_size_dpi_aware
          x = screen_width - @dialog_width - 10
          y = 20
		  @dialog.show
          @dialog.set_position(x, y)
		end
	  end

	  def ui_dir_path(subfolder)
		"file:///" + File.join(PATH_UI, subfolder).gsub("\\", "/") + "/"
	  end

	  def create_dialog
		html_file = File.join(PATH_UI, "html", "GN_ToolPathDialog.html")
		@@html_content = File.read(html_file)

        @@html_content.gsub!("../css/", ui_dir_path("css"))
        @@html_content.gsub!("../js/", ui_dir_path("js"))
        @@html_content.gsub!("../Scripts/", ui_dir_path("Scripts"))
						
		options = {
		  :dialog_title => @title,
		  :resizable => true,
          :width => @dialog_width,
          :height => @dialog_height,
		  :preferences_key => "example.htmldialog.materialinspector",
		  :style => UI::HtmlDialog::STYLE_UTILITY  # New feature!
		}
		dialog = UI::HtmlDialog.new(options)
		dialog.set_html(@@html_content) # Injecter le HTML modifié
#			dialog.set_file(html_file) # Can be set here.
		dialog.center # New feature!
		dialog.set_can_close { false }
		dialog
	  end
	  
	  def bind_dialog_callbacks
		@dialog.add_action_callback("fromJS") do |_ctx, msg|
		  handle_js_message(JSON.parse(msg))
		end
	  end
	  
	  def handle_js_message(msg)
		case msg["action"]

		when "material_changed"
		  update_material_value(msg["key"], msg["value"])

		when "view_mode"
		  set_view_mode(msg["mode"])

		when "apply_material"
		  apply_material

		when "add_toolpath"
		  add_toolpath(msg["type"],msg["key"],msg["defaults"])
		when "toolpath_delete"
		  del_toolpath(msg["id"])
		when "set_toolpath_visible"
		  set_visible_toolpath(msg["id"],msg["visible"])
		when "toolpath_type_setting"
		  toolpath_type_changed(msg)

		when "close_dialog"
		  @dialog&.close

		else
		  puts "[MaterialDialog] action inconnue : #{msg.inspect}"
		end
	  end
	  
	  def toolpath_type_changed(msg)
	  	@toolpath_type_setting = msg["type"]
		setModeFromtoolpath_type
	  end
	  
	  def update_dialog

		# update dialog data
        DrillBits.drillbitTbl.each do |oneDrill|
          @dialog.execute_script("window.addRowToTable('#{oneDrill.to_Json()}')")
        end
		scriptStr = "updateMaterialType(\'#{JSON.generate(Material::materialTypes)}\')"
		@dialog.execute_script(scriptStr)
	    scriptStr = "window.updateSchemas('#{JSON.generate(@schemas_hash)}')"
        @dialog.execute_script(scriptStr)
        @dialog.execute_script("window.selectToolpathType('#{@toolpath_type_setting}')")



		# send data for Material
		scriptStr = "window.setTitle('Material CNC')"
		@dialog.execute_script(scriptStr)
		boundingbox = @group.bounds
		if @material["safeHeight"] < boundingbox.depth.to_mm
		  @material["safeHeight"] = boundingbox.depth.to_mm + 5.mm
		end
		@material["materialHeight"] = boundingbox.depth.to_mm
		jsonStr = JSON.generate({
		  'material_type' => @material["material_type"],
		  'safeHeight' => @material["safeHeight"],
		  'materialHeight' => @material["materialHeight"],
		  'width' => boundingbox.width.to_mm.round(3),
		  'height' => boundingbox.height.to_mm.round(3),
		  'depth' => boundingbox.depth.to_mm.round(3),
		})
		scriptStr = "updateMaterial(\'#{jsonStr}\')"
		@dialog.execute_script(scriptStr)
		send_collection_to_dialog
	  end

      def send_collection_to_dialog
        return unless @hash_collection && @dialog
        loadCollection_json = "window.loadCollection('#{JSON.generate(@hash_collection)}')"
        @dialog.execute_script(loadCollection_json)
      end
	  
	  def open_dialog
		show_dialog
        attach_selection_observer
	  end

	  def on_dialog_closed
		@hash_collection = nil
        OverlayManager.set_collection(nil)
	  end
		
	  def close_dialog
		return unless @dialog
		if @undoRedoName == GNTools::OperationTracker.current_op and 
		   @undoRedoDepth == GNTools::OperationTracker.stack_depth
		  Sketchup.active_model.abort_operation()
		end
		detach_selection_observer
		@dialog.set_can_close { true }
		@dialog.close
	  end
	end

	module MaterialToolViewModeManager
	  def applyViewMode(mode)
		groups = Sketchup.active_model.entities.grep(Sketchup::Group)
		path_obj_list = groups.select { |g| GNTools::Paths.isGroupObj(g) }
		case mode
		when "original"
			Material::restore_original(@group)
			Sketchup.active_model.active_view.refresh
		when "current"
			Material::recreate_from_groupData(@group)
		when "path"
#			Material::restore_original(@group)
			Material::clear_all_geometry_except_paths(@group)
			original_json = @group.get_attribute(CNC_DICT, "originalData")
			return nil unless original_json
			Material::create_from_json(@group,original_json)
			# Créer une face dans le groupe
			face = @group.entities.add_face([0,0,0],[50.mm,0,0],[50.mm,50.mm,0],[0,50.mm,0])
			# Faire un pushpull
			face.pushpull(-10.mm)  # fonctionne parfaitement
#			path_obj_list.each do |obj|
#			  obj.createPath(@group)  # applique juste la géométrie
#			end
			Sketchup.active_model.active_view.refresh
		when "simulation"
			original_json = @group.get_attribute(CNC_DICT, "originalData")
			return nil unless original_json
			Material::clear_all_geometry_except_paths(@group)
			sousgroup = @group.entities.add_group
			Material::create_from_json(sousgroup,original_json)
			until_index = path_obj_list.count
			@group.entities.each {|entity| puts entity.inspect}
			sousgroup.explode
		end
	  end
	
	end

	class MaterialTool

	  @@tool_instance = nil
	  def self.tool_instance; @@tool_instance; end
	  def self.tool_instance=(v); @@tool_instance = v; end

	  include MaterialToolDialogManager
	  include MaterialToolViewModeManager
	  include MaterialToolDraw
	  include MaterialToolModeManager
	  include MaterialToolMouseEvents
	  
	  def initialize
	    @@tool_instance = self
		@active = false
        @state = :idle
		@dialog_width = 550
        @dialog_height = 820
		# Hash des schemas Toolpath (peut ne pas etre constant pour tout le cycle de vie)
		@schemas_hash = GNTools::NewPaths::ToolpathSchemas.toHash
		@toolpath_type_setting = "Hole"
		setModeFromtoolpath_type
		@hash_collection = {}
		OverlayManager.set_collection(@hash_collection)
	  end

      def activate
        @active = true
        @state = :idle
		# (peut ne pas etre constant pour tout le cycle de vie)
        @schemas_hash = GNTools::NewPaths::ToolpathSchemas.toHash

		model     = Sketchup.active_model
		selection = model.selection
		entities  = model.entities

		@title = "Material Settings"
		@undoRedoName = ""
		@undoRedoDepth = -1

		# -----------------------------
		# 1. Déterminer le groupe cible
		# -----------------------------
		@group = (selection.length == 1 && selection.first.is_a?(Sketchup::Group) ? selection.first : entities.add_group(selection.to_a))

		@material = GNTools::Material.new(@group)
		puts @material["toolpaths"]
		@hash_collection = Marshal.load(Marshal.dump(@material["toolpaths"]))
		OverlayManager.set_collection(@hash_collection)
		@viewMode = "current"  # "original", "current", "path", "simulation"

#        associer_collection
        open_dialog
        Sketchup.vcb_label = "Material Tool"
        Sketchup.vcb_value = ""
      end

      def deactivate(view)
        @active = false
		view.invalidate
		close_dialog
      end

	  def suspend(view)
	  end
	  
	  def resume(view)
		view.invalidate
	  end
		
	  def on_target_deselected
        close_dialog
        Sketchup.active_model.tools.pop_tool
      end
	
	  def dialog_opened
		if @material.isMaterial?
		  Sketchup.active_model.start_operation(GNTools::traduire("Edit Material"), true)
		  @undoRedoName = GNTools::OperationTracker.current_op
		  @undoRedoDepth = GNTools::OperationTracker.stack_depth
		  # Cas : déjà un groupe CNC/Material → on recharge les données

		  Material::save_group_data(@group)
		else
		  Sketchup.active_model.start_operation(GNTools::traduire("Create Material"), true)
		  @undoRedoName = GNTools::OperationTracker.current_op
		  @undoRedoDepth = GNTools::OperationTracker.stack_depth
				
		  @group.name = "Material CNC"
				
		  # Initialisation des valeurs par défaut via Material.default
		  # Écriture dans le groupe via Material
		  @material.write(@material.default)

		  Material::save_group_data(@group)
		end

		update_dialog
	  end
	
	  def add_toolpath(type,key,metadata,points = {})
		id = SecureRandom.uuid
		name = key
		visible = true
		pointshash = {}
		pointshash = points.map do |p| { 
			   "pos" => p.to_a, 
			   "attrs" =>  {}
			  }
		end
		@hash_collection[id] = {
						"name"=>name,
						"type"=>type,
						"metadata"=>Marshal.load(Marshal.dump(metadata)),
						"visible"=>true,
						"points"=>pointshash
						}	
		OverlayManager.set_collection(@hash_collection)							
		send_collection_to_dialog
	  end

	  def del_toolpath(key)
	    @hash_collection.delete(key)
		OverlayManager.set_collection(@hash_collection)	
	  end

	  def set_visible_toolpath(key,visible)
		@hash_collection[key]["visible"] = visible
		OverlayManager.set_collection(@hash_collection)
	  end

      # lightweight helpers for adding geometry/collection
      def add_point(pos)
        @points ||= []
        @points << pos
		@hash_collection ||= {}
		OverlayManager.set_collection(@hash_collection)	
#       puts "[ToolPathDialog] add_point #{pos}"
#		puts @schemas_hash[@toolpath_type_setting]["Rules"][:max_points]
		name = @toolpath_type_setting + "_" + (@hash_collection.size + 1).to_s
		add_toolpath(@toolpath_type_setting,name,@schemas_hash[@toolpath_type_setting]["Schema"],@points)
      end

      def add_segment(p1, p2)
        @points ||= []
        @points << p1
        @points << p2
		@hash_collection ||= {}
		OverlayManager.set_collection(@hash_collection)	
#       puts "[ToolPathDialog] add_segment #{p1} -> #{p2}"
		name = @toolpath_type_setting + "_" + (@hash_collection.size + 1).to_s
		add_toolpath(@toolpath_type_setting,name,@schemas_hash[@toolpath_type_setting]["Schema"],@points)
      end

      def add_segments(points)
        @points ||= []
        @points << p1
        @points << p2
		@hash_collection ||= {}
		OverlayManager.set_collection(@hash_collection)	
#       puts "[ToolPathDialog] add_segment #{p1} -> #{p2}"
		name = @toolpath_type_setting + "_" + (@hash_collection.size + 1).to_s
		add_toolpath(@toolpath_type_setting,name,@schemas_hash[@toolpath_type_setting]["Schema"],@points)
      end

      def add_arc(p1, p2, p3)
        @points ||= []
        @points << p1 << p2 << p3
 		name = @toolpath_type_setting + "_" + (@hash_collection.size + 1).to_s
		add_toolpath(@toolpath_type_setting,name,@schemas_hash[@toolpath_type_setting]["Schema"],@points)
#        puts "[ToolPathDialog] add_arc #{p1} #{p2} #{p3}"
      end

      def finalize_loop(points)
	  	@hash_collection ||= {}
		OverlayManager.set_collection(@hash_collection)
#		if @input_mode == :loop
#		   puts "closed loop"
#		end 
		name = @toolpath_type_setting + "_" + (@hash_collection.size + 1).to_s
		add_toolpath(@toolpath_type_setting,name,@schemas_hash[@toolpath_type_setting]["Schema"],@points)
        # example: create a closed polyline
#        puts "[ToolPathDialog] loop finalized with #{points.length/2} segments"
        @points = []
      end
	  
	  # -----------------------
	  #  Sélection Observer
	  # -----------------------
	  def attach_selection_observer
		@selection_observer = Class.new(Sketchup::SelectionObserver) do
		  def initialize(tool, target_group)
			@tool = tool
			@target_group = target_group
		  end

		  def onSelectionBulkChange(selection)
			check_selection(selection)
		  end

		  def onSelectionCleared(selection)
			check_selection(selection)
		  end

		  def onSelectionRemoved(selection, _entity)
			check_selection(selection)
		  end

		  def onSelectionAdded(selection, _entity)
			check_selection(selection)
		  end

		  private

		  def check_selection(selection)
			puts selection
			puts @target_group
			unless selection.include?(@target_group)
			  @tool.on_target_deselected
			end
		  end
		end.new(self, @group)

		Sketchup.active_model.selection.add_observer(@selection_observer)
	  end

	  def detach_selection_observer
		if @selection_observer
		  Sketchup.active_model.selection.remove_observer(@selection_observer)
		  @selection_observer = nil
		end
	  end		
    end

end #module GNTools