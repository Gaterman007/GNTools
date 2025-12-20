require 'sketchup.rb'
require 'json'

module GNTools

	
	class DefaultCNCData
		attr_accessor :project_Name
		attr_accessor :material_type
		attr_accessor :defaultFeedRate
		attr_accessor :defaultPlungeRate
		attr_accessor :defaultDepthLenght
		
		attr_accessor :safeHeight
		attr_accessor :material_width
		attr_accessor :material_thickness
		attr_accessor :material_depth
		
		attr_accessor :startGCode
		attr_accessor :endGCode
		attr_accessor :safeZoneHeight
		attr_accessor :safeZoneDepth
		attr_accessor :safeZoneWidth
		
		
		attr_accessor :materialObjet
		attr_accessor :show_Material
		attr_accessor :LengthPrecision

		DefautDictName = "DEFCNCDataTest" unless defined?(DefautDictName)

		def initialize()
			self.initCNCData
		end

		def initCNCData
			#Acrylic: 635 mm/s (feed), 228.6 mm/s (plunge), 0.5 mm (depth)
			#Aluminum: 127 mm/s (feed), 76.2 mm/s (plunge), 0.1 mm (depth)
			#Birch Plywood: 762 mm/s (feed), 228.6 mm/s (plunge), 0.7 mm (depth)
			#Cherry Plywood: 609.6 mm/s (feed), 228.6 mm/s (plunge), 0.8 mm (depth)
			@project_Name = nil
			@material_type = "Acrylic"
			@defaultFeedRate = 635
			@defaultPlungeRate = 228.6
			@defaultDepthLenght = 0.5
			@safeHeight = 6
			@material_width = 2
			@material_thickness = 20
			@material_depth = 4
			@safeZoneHeight = 20
			@safeZoneDepth = 170
			@safeZoneWidth = 120
			
			
			@startGCode = "G21 ;Set units to millimeters\\nG90 ;Absolute Positioning\\nG92 X0 Y0;Set Postion X to 0 Y to 0"
			@endGCode = "G90"
			@show_Material = false
			@materialObjetID = nil
			@materialObjet = nil
			@LengthPrecision = Sketchup.active_model.options["UnitsOptions"]["LengthPrecision"]
# tout les possibiliter pour units = Sketchup.active_model.options["UnitsOptions"]			
#			LengthPrecision			# Nombre de décimales ou fraction
#			LengthFormat			# 0 = Décimal, 1 = Fraction, 2 = Scientifique, 3 = Ingénieur
#			LengthUnit				# 0 = Pouces, 1 = Pieds, 2 = Millimètres, 3 = Centimètres, 4 = Mètres
#			LengthSnapEnabled
#			LengthSnapLength
#			AnglePrecision
#			AngleSnapEnabled
#			SnapAngle
#			SuppressUnitsDisplay
#			ForceInchDisplay
#			AreaUnit
#			VolumeUnit
#			AreaPrecision
#			VolumePrecision
		end

		def dup
			copy = super
			copy.from_Hash(self.create_Hash)
			copy
		end

		def to_model
			# Vérifier s'il existe déjà un CPoint avec notre identifiant
			group_Material = Sketchup.active_model.entities.grep(Sketchup::Group).find { |cp| cp.attribute_dictionaries && cp.attribute_dictionaries["DEFCNCDataTest"] }
			unless group_Material
			  group_Material = Sketchup.active_model.entities.add_group
			  group_Material.name = "Material_data"
              cpoint = group_Material.entities.add_cpoint([0, 0, 0])
			  group_Material.visible = false # On le cache
			  group_Material.locked = true # On le verrouille pour éviter la suppression
			end
		    # Ajouter un identifiant unique et des données
		    group_Material.set_attribute( DefautDictName,"width", @material_width)
			group_Material.set_attribute( DefautDictName,"project_Name",@project_Name )
			group_Material.set_attribute( DefautDictName,"material_type", @material_type )
			group_Material.set_attribute( DefautDictName,"safeHeight", @safeHeight )
			group_Material.set_attribute( DefautDictName,"width", @material_width )
			group_Material.set_attribute( DefautDictName,"height", @material_thickness )
			group_Material.set_attribute( DefautDictName,"depth", @material_depth )
			group_Material.set_attribute( DefautDictName,"startGCode", @startGCode )
			group_Material.set_attribute( DefautDictName,"endGCode", @endGCode )
			group_Material.set_attribute( DefautDictName,"show_Material", @show_Material )
			group_Material.set_attribute( DefautDictName,"safeZoneHeight", @safeZoneHeight )
			group_Material.set_attribute( DefautDictName,"safeZoneDepth", @safeZoneDepth )
			group_Material.set_attribute( DefautDictName,"safeZoneWidth", @safeZoneWidth )
			if @show_Material && (@materialObjet != nil)
			  group_Material.set_attribute( DefautDictName,"materialID", @materialObjet.persistent_id )
			else
			  group_Material.set_attribute( DefautDictName,"materialID", nil )			
			end
		end

		def self.getFromModel(key)
			group_Material = Sketchup.active_model.entities.grep(Sketchup::Group).find { |cp| cp.attribute_dictionaries && cp.attribute_dictionaries[DefautDictName] }
			if group_Material
				if group_Material.attribute_dictionary(DefautDictName).keys.include?(key)
					return group_Material.get_attribute(DefautDictName, key)
				end
			end
			return nil
		end

		def find_entity_by_persistent_id(pid)
		  find_entity_by_persistent_id_recursive(Sketchup.active_model.entities,pid)
		end

		def find_entity_by_persistent_id_recursive(entities,pid)
		  entities.each do |entity|
			return entity if entity.persistent_id == pid

			# Si l'entité est un groupe ou une instance de composant, explorer son contenu
			if entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
			  found = find_entity_by_persistent_id_recursive(entity.definition.entities, pid)
			  return found if found
			end
		  end
		  nil  # Si aucune entité ne correspond
		end
		
		def from_model
			# Vérifier s'il existe déjà un group avec les infos
			group_Material = Sketchup.active_model.entities.grep(Sketchup::Group).find { |cp| cp.attribute_dictionaries && cp.attribute_dictionaries[DefautDictName] }
			if group_Material
				@project_Name = group_Material.get_attribute(DefautDictName, "project_Name")
				@material_type = group_Material.get_attribute(DefautDictName, "material_type")
				@safeHeight = group_Material.get_attribute(DefautDictName, "safeHeight")
				@material_width = group_Material.get_attribute(DefautDictName, "width")
				@material_thickness = group_Material.get_attribute(DefautDictName, "height")
				@material_depth = group_Material.get_attribute(DefautDictName, "depth")
				@startGCode = group_Material.get_attribute(DefautDictName, "startGCode")
				@endGCode = group_Material.get_attribute(DefautDictName, "endGCode") 
				@show_Material = group_Material.get_attribute(DefautDictName, "show_Material")
				@materialObjetID = group_Material.get_attribute(DefautDictName, "materialID")
				if @materialObjetID
					@materialObjet = find_entity_by_persistent_id(@materialObjetID)
				else
					@materialObjet = nil
				end
				@safeZoneHeight = group_Material.get_attribute( DefautDictName,"safeZoneHeight")
				@safeZoneDepth =  group_Material.get_attribute( DefautDictName,"safeZoneDepth")
				@safeZoneWidth =  group_Material.get_attribute( DefautDictName,"safeZoneWidth")
				return true
			end
			return false
		end

		def to_Json()
			JSON.generate({
				'project_Name'  => @project_Name,
				'material_type' => @material_type,
				'safeHeight' => @safeHeight,
				'width' => @material_width,
				'height' => @material_thickness,
				'depth' => @material_depth,
				'startGCode' => @startGCode,
				'endGCode' => @endGCode,
				'safeZoneHeight' => @safeZoneHeight,
				'safeZoneDepth' => @safeZoneDepth,
				'safeZoneWidth' => @safeZoneWidth,
				'show_Material' => @show_Material,
				'materialID' => @materialObjetID
			})
		end
		
		def fromJson(jsonStr)
			hash = JSON.parse(jsonStr)
			self.from_Hash(hash)
		end
		
		def from_Hash(hash)
			@project_Name = hash["project_Name"]
			@material_type = hash["material_type"]
			@safeHeight = hash["safeHeight"]
			@material_width = hash["width"]
			@material_thickness = hash["height"]
			@material_depth = hash["depth"]
			@startGCode = hash["startGCode"]
			@endGCode = hash["endGCode"]
			@safeZoneHeight = hash["safeZoneHeight"]
			@safeZoneDepth = hash["safeZoneDepth"]
			@safeZoneWidth = hash["safeZoneWidth"]
			@show_Material = hash["show_Material"]
			@materialObjetID = hash["materialID"]
		end

		def create_Hash()
			hash = {
			"project_Name"  => @project_Name,
			"material_type" => @material_type,
			"safeHeight" => @safeHeight,
			"width" => @material_width,
			"height" => @material_thickness,
			"depth" => @material_depth,
			"startGCode" => @startGCode,
			"endGCode" => @endGCode,
			"safeZoneHeight" => @safeZoneHeight,
			"safeZoneDepth" => @safeZoneDepth,
			"safeZoneWidth" => @safeZoneWidth,
			"show_Material" => @show_Material,
			"materialID" => @materialObjetID
			}
			hash
		end

	end

	class DefaultCNCDialog

		@@default_FileName = "DefaultCNCData.txt"

		@@def_CNCData = DefaultCNCData.new
				
		# initialize the default data
		def self.set_defaults
			@@def_CNCData.initCNCData
			# Vérifier s'il existe déjà un Group avec notre identifiant
			group_Material = Sketchup.active_model.entities.grep(Sketchup::Group).find { |cp| cp.attribute_dictionaries && cp.attribute_dictionaries["DEFCNCDataTest"] }			
			if group_Material
				@@def_CNCData.from_model()
			else
				if File.exist?(File.join(GNTools::PATH_ROOT, @@default_FileName))
					self.loadFromFile()
				else
					@@def_CNCData = DefaultCNCData.new
					self.saveToFile()
				end
			end
		end

		def self.def_CNCData
			@@def_CNCData
		end

		def self.CNCData(key)
			group_Material = Sketchup.active_model.entities.grep(Sketchup::Group).find { |cp| cp.attribute_dictionaries && cp.attribute_dictionaries[DefautDictName] }
			if group_Material
				return group_Material.attribute_dictionary(DefautDictName, false)&.has_key?(key)
			end
			return nil
		end

		def show_dialog
			if @dialog && @dialog.visible?
				self.update_dialog
				@dialog.set_size(840, 800)
				@dialog.bring_to_front
			else
				# Attach content and callbacks when showing the dialog,
				# not when creating it, to be able to use the same dialog again.
				@dialog ||= self.create_dialog
				@dialog.add_action_callback("ready") { |action_context|
					self.update_dialog
					nil
				}
				# set to model only
				@dialog.add_action_callback("accept") { |action_context, value|
					tmp_CNCData = DefaultCNCData.new
					tmp_CNCData.from_Hash(value)
					tmp_CNCData.startGCode = value["startGCode"].gsub(/\R+|\//, '\\\\n')
					tmp_CNCData.endGCode = value["endGCode"].gsub(/\R+|\//, '\\\\n')
					tmp_CNCData.materialObjet = @@def_CNCData.materialObjet
					tmp_CNCData.to_model
					@dialog.close
					Sketchup.active_model.select_tool(nil)
					nil
				}
				@dialog.add_action_callback("cancel") { |action_context, value|
					@dialog.close
					Sketchup.active_model.select_tool(nil)
					nil
				}

				@dialog.add_action_callback("reset") { |action_context, value|
					self.update_dialog
					nil
				}

				# set Default values
				@dialog.add_action_callback("apply") { |action_context, value|
					@@def_CNCData.from_Hash(value)
					@@def_CNCData.startGCode = value["startGCode"].gsub(/\R+|\//, '\\\\n')
					@@def_CNCData.endGCode = value["endGCode"].gsub(/\R+|\//, '\\\\n')
					DefaultCNCDialog.saveToFile()
					nil
				}
				@dialog.add_action_callback("newValue") { |action_context, valueName, onevalue|
					if @@def_CNCData.materialObjet != nil
						if valueName == "show_Material"
							if onevalue["show_Material"]
								@@def_CNCData.materialObjet.visible = true
							else
								@@def_CNCData.materialObjet.visible = false
							end
						end
					end
					nil
				}
				@dialog.add_action_callback("showResult") { |action_context, value|
					if @@def_CNCData.materialObjet != nil
						Sketchup.active_model.start_operation(GNTools::traduire("Show Result"), true)
						group = @@def_CNCData.materialObjet
						groupcopy = group.copy
						GNTools.pathObjList.values.each do |pathObj|
							delPath = pathObj.pathEntitie.copy
							groupcopy = delPath.subtract(groupcopy)
						end
						groupcopy.name = "CNC Resultat"
						Sketchup.active_model.commit_operation
					end
					nil
				}
				@dialog.set_size(840, 800)
				@dialog.show
			end
		end
		
		def create_cube(xsize, ysize, zsize)
		  model = Sketchup.active_model
		  entities = model.active_entities

		  # Créer un groupe
		  group = entities.add_group

		  group = self.modify_cube(group,xsize, ysize, zsize)
		  group.name = "CNC Material"
		  return group
		end		

		def modify_cube(group,xsize, ysize, zsize)
		  group_entities = group.entities
		  position = []
		  group_entities.each do |entity|
			if !entity.is_a?(Sketchup::ConstructionPoint)
				group_entities.erase_entities(entity)
			else
				position << entity.position
			end
		  end
		  # Définition des points du parallélépipède
		  points = [
			[0, 0, 0], [xsize, 0, 0], [xsize, ysize, 0], [0, ysize, 0], # Base
			[0, 0, zsize], [xsize, 0, zsize], [xsize, ysize, zsize], [0, ysize, zsize] # Haut
		  ]

		  # Définition des faces
		  faces = [
			[0, 1, 2, 3], # Bas
			[4, 5, 6, 7], # Haut
			[0, 1, 5, 4], # Devant
			[1, 2, 6, 5], # Droite
			[2, 3, 7, 6], # Arrière
			[3, 0, 4, 7]  # Gauche
		  ]

		  # Ajouter les faces au groupe
		  faces.each do |face|
			group_entities.add_face(points[face[0]], points[face[1]], points[face[2]], points[face[3]])
		  end

		  return group
		end		

		
		def close_dialog
			if @dialog
				@dialog.set_can_close { true }
				@dialog.close
			end
		end
		
		def create_dialog
			html_file = File.join(PATH_UI, 'html', 'CNC_Params.html') # Use external HTML
			options = {
			  :dialog_title => "Material Settings",
			  :resizable => true,
			  :width => 840,
			  :height => 800,
			  :preferences_key => "example.htmldialog.materialinspector",
			  :style => UI::HtmlDialog::STYLE_UTILITY  # New feature!
			}
			dialog = UI::HtmlDialog.new(options)
			dialog.set_file(html_file) # Can be set here.
#			dialog.center # New feature!
#			dialog.set_can_close { false }
			dialog
		end
		
		def update_dialog
			tmp_CNCData = DefaultCNCData.new
			if not tmp_CNCData.from_model
				tmp_CNCData = @@def_CNCData.dup
			end
			scriptStr = "updateDialog(\'#{tmp_CNCData.to_Json()}\')"
			@dialog.execute_script(scriptStr)
		end
		
		def self.saveToFile()
			file = File.open(File.join(GNTools::PATH_ROOT, @@default_FileName), "w")
			file.write(@@def_CNCData.to_Json)
			file.close
		end
		
		def self.loadFromFile()
			File.foreach(File.join(GNTools::PATH_ROOT, @@default_FileName)) { |line|
				@@def_CNCData.fromJson(line)
				
			}
		end
	end

	class DefaultCNCTool

		@@DefaultCNCDia = DefaultCNCDialog.new()

		def activate
			@mouse_pos_down = ORIGIN
			@mouse_ip = Sketchup::InputPoint.new
			@picked_first_ip = Sketchup::InputPoint.new
			@dragged = false
			@mouseButton = false
			@state = 0
#		si on a a faire quelquechose avec la selection c est ici
			model = Sketchup.active_model
			sel = Sketchup.active_model.selection
			if (sel.count > 0) then
				if DefaultCNCDialog.def_CNCData.materialObjet == nil && !Paths::isGroupObj(sel[0])
					if sel[0].typename == "Group"
						DefaultCNCDialog.def_CNCData.materialObjet = sel[0]
						sel[0].name = "CNC Material"
						boundingBox = sel[0].bounds
						DefaultCNCDialog.def_CNCData.material_width = boundingBox.width.to_mm					# X axis
						DefaultCNCDialog.def_CNCData.material_thickness = boundingBox.depth.to_mm				# Z axis
						DefaultCNCDialog.def_CNCData.material_depth = boundingBox.height.to_mm					# Y axis
						DefaultCNCDialog.def_CNCData.safeHeight = boundingBox.depth.to_mm + 10 # #10 mm plus haut 
						DefaultCNCDialog.def_CNCData.show_Material = true
					end
				else
					if DefaultCNCDialog.def_CNCData.materialObjet != nil
						if DefaultCNCDialog.def_CNCData.materialObjet.deleted?
							DefaultCNCDialog.def_CNCData.materialObjet = nil
						else
							group = DefaultCNCDialog.def_CNCData.materialObjet
							boundingBox = group.bounds
							DefaultCNCDialog.def_CNCData.material_width = boundingBox.width.to_mm				# X axis
							DefaultCNCDialog.def_CNCData.material_thickness = boundingBox.depth.to_mm			# Z axis
							DefaultCNCDialog.def_CNCData.material_depth = boundingBox.height.to_mm				# Y axis
							DefaultCNCDialog.def_CNCData.safeHeight = boundingBox.depth.to_mm + 10 # #10 mm plus haut 
							DefaultCNCDialog.def_CNCData.show_Material = true
						end
					end
				end
			end
			self.show_dialog
		end
		
		def deactivate(view)
			view.invalidate
			self.close_dialog
		end
		
		def resume(view)
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
			@mouse_down = Geom::Point3d.new(x, y)
			@mouse_ip.pick(view, x, y)
			view.invalidate		
		end
		
		def onMouseMove(flags, x, y, view)
			if @mouseButton
				if (!@dragged) && (@mouse_down.distance([x, y]) > 10)
					@dragged = true
				end
			end
			if @picked_first_ip.valid?
				@mouse_ip.pick(view, x, y, @picked_first_ip)
			else
				@mouse_ip.pick(view, x, y)
			end

			view.tooltip = @mouse_ip.tooltip if @mouse_ip.valid?
			view.invalidate
		end
		
		def onLButtonUp(flags, x, y, view)
			if @state == 2
				@picked_first_ip.clear
				@state = 0
			end
			if @state == 1
				if @dragged
					@picked_first_ip.clear
					@state = 0
				end
			end
			@mouseButton = false
			@dragged = false
			view.invalidate
			model = Sketchup.active_model
			model.selection.clear
		end
		
		def onSetCursor
			UI.set_cursor(632)
		end

		def draw(view)
			draw_preview(view)
			@mouse_ip.draw(view) if @mouse_ip.display?
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
		
		def picked_points
		  points = []
		  points << @picked_first_ip.position if @picked_first_ip.valid?
		  points << @mouse_ip.position if @mouse_ip.valid?
		  points
		end


		def reset_tool
		end

		def show_dialog
			@@DefaultCNCDia.show_dialog
		end
		
		def close_dialog
			@@DefaultCNCDia.close_dialog
		end
		
		def create_dialog
			@@DefaultCNCDia.create_dialog
		end
		
		def update_dialog
			@@DefaultCNCDia.update_dialog
		end

	end


end  #module GNTools
