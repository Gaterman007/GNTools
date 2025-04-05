# Copyright 2018, Gaetan Noiseux, based loosely on linetool.rb by @Last Software, Inc.

# THIS SOFTWARE IS PROVIDED "AS IS" AND WITHOUT ANY EXPRESS OR
# IMPLIED WARRANTIES, INCLUDING, WITHOUT LIMITATION, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
#-----------------------------------------------------------------------------

require 'sketchup.rb'

module GNTools

  #-----------------------------------------------------------------------------
  # The mouse IO is based on lineTool.rb from the Google Ruby API examples programmes, modified by Francis Mc Shane to accept 3 points instead of 2.
  # Circle3X3DPoints changes the original lineTool create_geometry method to return 3 point objects to draw a circle from those 3 points.
  # The plugin draws a circle on the plane of the 3 three dimensional input points with the circumferance through the input points.

  class Circle3X3DPoints

    # This is the standard Ruby initialize method that is called when you create
    # a new object.
    def initialize(center = true)
      @ip1 = nil
      @ip2 = nil
      @ip3 = nil
      @xdown = 0
      @ydown = 0
      @center = center
    end

    # The activate method is called by SketchUp when the tool is first selected.
    # it is a good place to put most of your initialization
    def activate    # The Sketchup::InputPoint class is used to get 3D points from screen
      # positions.  It uses the SketchUp inferencing code.
      @ip1 = Sketchup::InputPoint.new
      @ip2 = Sketchup::InputPoint.new
      @ip3 = Sketchup::InputPoint.new
      @ip = Sketchup::InputPoint.new
      @drawn = false

      # This sets the label for the VCB
      Sketchup::set_status_text traduire("Length"), SB_VCB_LABEL
      
      self.reset(nil)
    end

    # deactivate is called when the tool is deactivated because
    # a different tool was selected
    def deactivate(view)
      view.invalidate if @drawn
    end

    # The onMouseMove method is called whenever the user moves the mouse.
    # because it is called so often, it is important to try to make it efficient.
    # In a lot of tools, your main interaction will occur in this method.
    def onMouseMove(flags, x, y, view)
      case @state
      when 0
        # We are getting the first end of the line.  Call the pick method
        # on the InputPoint to get a 3D position from the 2D screen position
        # that is based as an argument to this method.
        @ip.pick view, x, y
        if( @ip != @ip1 )
          # if the point has changed from the last one we got, then
          # see if we need to display the point.  We need to display it
          # if it has a display representation or if the previous point
          # was displayed.  The invalidate method on the view is used
          # to tell the view that something has changed so that you need
          # to refresh the view.
          view.invalidate if( @ip.display? or @ip1.display? )
          @ip1.copy! @ip
          
          # set the tooltip that should be displayed to this point
          view.tooltip = @ip1.tooltip
        end
      when 1
        # Getting the second end of the line
        # If you pass in another InputPoint on the pick method of InputPoint
        # it uses that second point to do additional inferencing such as
        # parallel to an axis.
        @ip2.pick view, x, y, @ip1
        view.tooltip = @ip2.tooltip if( @ip2.valid? )
        view.invalidate
        
        # Update the length displayed in the VCB
        if( @ip2.valid? )
          length = @ip1.position.distance(@ip2.position)
          Sketchup::set_status_text length.to_s, SB_VCB_VALUE
        end
        
        # Check to see if the mouse was moved far enough to create a line.
        # This is used so that you can create a line by either draggin
        # or doing click-move-click
        if( (x-@xdown).abs > 10 || (y-@ydown).abs > 10 )
          @dragging = true
        end
      when 2
        # Getting the second end of the line
        # If you pass in another InputPoint on the pick method of InputPoint
        # it uses that second point to do additional inferencing such as
        # parallel to an axis.
        @ip3.pick view, x, y, @ip2
        view.tooltip = @ip3.tooltip if( @ip3.valid? )
        view.invalidate
        
        # Update the length displayed in the VCB
        if( @ip3.valid? )
          length = @ip2.position.distance(@ip3.position)
          Sketchup::set_status_text length.to_s, SB_VCB_VALUE
        end
        
        # Check to see if the mouse was moved far enough to create a line.
        # This is used so that you can create a line by either draggin
        # or doing click-move-click
        if( (x-@xdown).abs > 10 || (y-@ydown).abs > 10 )
          @dragging = true
        end	
      end
    end

    # The onLButtonDOwn method is called when the user presses the left mouse button.
    def onLButtonDown(flags, x, y, view)
      # When the user clicks the first time, we switch to getting the
      # second and third point.  When they click a third time we create the geometry
      case @state
      when 0
        @ip1.pick view, x, y
        if( @ip1.valid? )
          @state = 1
          Sketchup::set_status_text traduire("Select second point on circle."), SB_PROMPT
          @xdown = x
          @ydown = y
        end
      when 1
        # get second point on the second click
        @ip2.pick view, x, y
        if( @ip2.valid? )
          @state = 2
          Sketchup::set_status_text traduire("Select third and last point on circle."), SB_PROMPT
          @xdown = x
          @ydown = y
        end
      when 2
        # create the geometry on the third click
        if( @ip3.valid? )
          self.create_geometry(@ip1.position, @ip2.position, @ip3.position,view)
          self.reset(view)
        end
      end
      
      # Clear any inference lock
      view.lock_inference
    end

    # The onLButtonUp method is called when the user releases the left mouse button.
    def onLButtonUp(flags, x, y, view)
      # If we are doing a drag, then create the geometry on the mouse up event
      if( @dragging && @ip3.valid? )
        if @ip2.position != @ip3.position
         self.create_geometry(@ip1.position, @ip2.position, @ip3.position,view)
        end 
        self.reset(view)
      end
    end

    # onKeyDown is called when the user presses a key on the keyboard.
    # We are checking it here to see if the user pressed the shift key
    # so that we can do inference locking
    def onKeyDown(key, repeat, flags, view)
      if( key == CONSTRAIN_MODIFIER_KEY && repeat == 1 )
        @shift_down_time = Time.now
        
        # if we already have an inference lock, then unlock it
        if( view.inference_locked? )
          # calling lock_inference with no arguments actually unlocks
          view.lock_inference
        elsif( @state == 0 && @ip1.valid? )
          view.lock_inference @ip1
        elsif( @state == 1 && @ip2.valid? )
          view.lock_inference @ip2, @ip1
        elsif( @state == 1 && @ip3.valid? )
          view.lock_inference @ip3, @ip2
        end
      end
    end

    # onKeyUp is called when the user releases the key
    # We use this to unlock the inference
    # If the user holds down the shift key for more than 1/2 second, then we
    # unlock the inference on the release.  Otherwise, the user presses shift
    # once to lock and a second time to unlock.
    def onKeyUp(key, repeat, flags, view)
      if( key == CONSTRAIN_MODIFIER_KEY &&
        view.inference_locked? &&
        (Time.now - @shift_down_time) > 0.5 )
        view.lock_inference
      end
    end
    
    # The draw method is called whenever the view is refreshed.  It lets the
    # tool draw any temporary geometry that it needs to.
    def draw(view)
      if( @ip1.valid? )
        if( @ip1.display? )
          @ip1.draw(view)
          @ip2.draw(view)
          @drawn = true
        end        
        if( @ip3.valid? )
          @ip3.draw(view) if( @ip3.display? )
          
          # The set_color_from_line method determines what color
          # to use to draw a geometry based on its direction.  For example
          # red, green or blue.
          #view.set_color_from_line(@ip1, @ip2, @ip3)
          self.draw_geometry(@ip1.position, @ip2.position, @ip3.position,view)
          @drawn = true
        end
      end
    end

    # onCancel is called when the user hits the escape key
    def onCancel(flag, view)
      self.reset(view)
    end


    # The following methods are not directly called from SketchUp.  They are
    # internal methods that are used to support the other methods in this class.

    # Reset the tool back to its initial state
    def reset(view)
      # This variable keeps track of which point we are currently getting
      @state = 0
      
      # Display a prompt on the status bar
      Sketchup::set_status_text(traduire("Select first end"), SB_PROMPT)
      
      # clear the InputPoints
      @ip1.clear
      @ip2.clear
      @ip3.clear
      
      if( view )
        view.tooltip = nil
        view.invalidate if @drawn
      end
      
      @drawn = false
      @dragging = false
    end
    
    
  #__________________________________________________________	
    # Create circle when the user has selected 3 points.
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

    def circleCenterVectorAndRadius(pt1, pt2, pt3, view)
    # Draw a circle on the plane determined by the 3 points with circumference located on the 3 input points.
      #1st determine the midpoint of pt1 and pt2
      midpoint_of_3Dpoints_p1_p2 = midpoint_of_3Dpoints(pt1, pt2)
      #2nd determine the midpoint of pt2 and pt3
      midpoint_of_3Dpoints_p2_p3 = midpoint_of_3Dpoints(pt2, pt3)
      #determin the perpendicular bisector of points p1 and p2 on plane defined by points p1,p2 and p3
#      line_p1_p2 = [pt1, pt2] #note that although the line is defined by 2 points it is infinite. See Sketchup GEOM module.
      vector_from_line_p1_p2 = Geom::Vector3d.new pt1.x - pt2.x, pt1.y - pt2.y, pt1.z - pt2.z
      vector_from_line_p2_p3 = Geom::Vector3d.new pt2.x - pt3.x, pt2.y - pt3.y, pt2.z - pt3.z
      vector_verticle = vector_from_line_p1_p2.cross vector_from_line_p2_p3
      rotate_90_degrees_transform = Geom::Transformation.rotation midpoint_of_3Dpoints_p1_p2, vector_verticle , Math::PI/2 #90degrees
      vector_perpendicular_to_line_p1_p2 = Geom::Vector3d.new vector_from_line_p1_p2
      vector_perpendicular_to_line_p1_p2.transform! rotate_90_degrees_transform
      vector_perpendicular_to_line_p2_p3 = Geom::Vector3d.new vector_from_line_p2_p3
      vector_perpendicular_to_line_p2_p3.transform! rotate_90_degrees_transform
      centre_point = Geom.intersect_line_line [midpoint_of_3Dpoints_p1_p2,vector_perpendicular_to_line_p1_p2], [midpoint_of_3Dpoints_p2_p3,vector_perpendicular_to_line_p2_p3]
      radius = pt1.distance centre_point
      centerVectorAndRadius = [centre_point,vector_verticle,radius]  #center of circle, the plane of circle, radius
      centerVectorAndRadius
    end


    
    def perpendicular_bisector(midpoint, p1, p2, p3)	
      #determin the perpendicular bisector of points p1 and p2 on plane defined by points p1,p2 and p3
      line_p1_p2 = [p1, p2] #note that although the line is defined by 2 points it is infinite. See Sketchup GEOM module.
      vector_from_line_p1_p2 = Geom::Vector3d.new p1.x - p2.x, p1.y - p2.y, p1.z - p2.z
      vector_from_line_p2_p3 = Geom::Vector3d.new p2.x - p3.x, p2.y - p3.y, p2.z - p3.z
      vector_verticle = vector_from_line_p1_p2.cross vector_from_line_p2_p3
      rotate_90_degrees_transform = Geom::Transformation.rotation midpoint, vector_verticle , Math::PI/2 #90degrees
      vector_perpendicular_to_line_p1_p2 = Geom::Vector3d.new vector_from_line_p1_p2
      vector_perpendicular_to_line_p1_p2.transform! rotate_90_degrees_transform
      perp_to_line_p1_p2_and_its_normal = [midpoint, vector_perpendicular_to_line_p1_p2, vector_verticle] #the line (defined by a point and a vector, see Sketchup GEOM module) which bisects the finite line joining p1 and p2 at right angles.
      perp_to_line_p1_p2_and_its_normal
    end # of perpendicular_bisector(midpoint, p1, p2, p3)
    
    def create_geometry(pt1, pt2, pt3, view)	
    # Draw a circle on the plane determined by the 3 points with circumference located on the 3 input points.
      #1st determine the midpoint of pt1 and pt2
      midpoint_of_3Dpoints_p1_p2 = midpoint_of_3Dpoints(pt1, pt2)
      #2nd determine the midpoint of pt2 and pt3
      midpoint_of_3Dpoints_p2_p3 = midpoint_of_3Dpoints(pt2, pt3)
      #3rd determine the perpendicular_bisector_p1_p2_on_plane_p1p2p3
      perpendicular_bisector_p1_p2_on_plane_p1p2p3_and_its_normal = perpendicular_bisector(midpoint_of_3Dpoints_p1_p2, pt1, pt2, pt3)#perpendicular_bisector returns an array of a point, a line (the perpendicular bisector) and a vector normal to the plane of the line and points pt1, pt2 and pt3  
      perpendicular_bisector_p1_p2_on_plane_p1p2p3 = [perpendicular_bisector_p1_p2_on_plane_p1p2p3_and_its_normal[0],perpendicular_bisector_p1_p2_on_plane_p1p2p3_and_its_normal[1]] #this array defines the line of the perpendicular bisector
      #4th determine the perpendicular_bisector_p2_p3_on_plane_p2p3p1
      perpendicular_bisector_p2_p3_on_plane_p2p3p1_and_its_normal = perpendicular_bisector(midpoint_of_3Dpoints_p2_p3, pt2, pt3, pt1)#perpendicular_bisector returns an array of a point, a line (the perpendicular bisector) and a vector normal to the plane of the line and points pt1, pt2 and pt3 
      perpendicular_bisector_p2_p3_on_plane_p2p3p1 = [perpendicular_bisector_p2_p3_on_plane_p2p3p1_and_its_normal[0],perpendicular_bisector_p2_p3_on_plane_p2p3p1_and_its_normal[1]] #this array defines the line of the perpendicular bisector
      vector_verticle = perpendicular_bisector_p1_p2_on_plane_p1p2p3_and_its_normal[2]
      #where the 2 perpendicular bisectors cross is the centre of the circle. The 3 points pt1, pt2 and pt3 are an inscribed triangle within the circle with this centre, the points being on the circle's circumference.
      centre_point = Geom.intersect_line_line perpendicular_bisector_p1_p2_on_plane_p1p2p3, perpendicular_bisector_p2_p3_on_plane_p2p3p1
      if centre_point == nil
        then UI.messagebox("Oops, something strange happened. Maybe the points are in a straight line? The perpendicular bisectors to the lines joining the 3 points do not cross:(")
      else # draw the circle
#        UI.messagebox("Sketchup makes circles from straight line segments. The standard number of segments is 24. These are unlikely to touch the 3 points exactly but you can increase the number of segments and thereby the closeness of fit to the 3 points by selecting the circle, right clicking it, select \'Entity Info\' from the context menu then increase the number of segments in the dialog box which appears. The circle will be drawn more or less rounded depending on the number of segments you enter. Be careful, though; too many segments could stretch your computer's memory beyond it's limit. If you want to check the exact radius of the circle just start the Sketchup Ruby console and run the plugin. The radius will be output during the plugin's run. The precision of the output can be set in the Sketchup menu item Window/Model Info under Precision in the Units dialog box.")
        model = Sketchup.active_model	 
        if @center
          # start of one click undo	
          model.start_operation "Construction points"
          entities = model.active_entities
          entities.add_cpoint centre_point
          entities.add_cpoint pt1
          entities.add_cpoint pt2
          entities.add_cpoint pt3
          model.commit_operation
        else
          # start of one click undo	
          model.start_operation "Construction lines"
          radius =  pt1.distance centre_point
          entities = model.active_entities
          # Verbose or quiet mode
          answer = UI.messagebox("Without construction lines?", MB_YESNO)
          if answer==6
          else
            entities.add_cpoint pt1
            entities.add_cpoint pt2
            entities.add_cpoint pt3
            entities.add_cpoint midpoint_of_3Dpoints_p1_p2
            entities.add_cpoint midpoint_of_3Dpoints_p2_p3
            entities.add_cline perpendicular_bisector_p1_p2_on_plane_p1p2p3[0],perpendicular_bisector_p1_p2_on_plane_p1p2p3[1]
            entities.add_cline perpendicular_bisector_p2_p3_on_plane_p2p3p1[0],perpendicular_bisector_p2_p3_on_plane_p2p3p1[1]
          end
          model.commit_operation
          # end of one click undo	 
          # start of one click undo	
          model.start_operation "Circle from 3 points"
          edgearray = view.model.entities.add_circle centre_point, vector_verticle, radius
          first_edge = edgearray[0]
          arccurve = first_edge.curve
          # end of one click undo
          model.commit_operation
        end
      end

    end # of create_geometry(pt1, pt2, pt3, view)
    
    # Draw the geometry
    def draw_geometry(pt1, pt2, pt3, view)
      if pt3 != pt2
        cvr = circleCenterVectorAndRadius(pt1, pt2, pt3, view)
        pt4 = cvr[0]
        view.draw_points([pt1, pt2, pt3, pt4], 5, 2 , "red")
      end
    end
  end
end