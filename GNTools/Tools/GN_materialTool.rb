require 'sketchup.rb'
require 'json'

module GNTools

	MATERIAL_DICT = "Material" unless const_defined?(:MATERIAL_DICT)

	def self.is_cnc_group(entity, key = nil)
		return nil unless entity.is_a?(Sketchup::Group)

		# Liste des dictionnaires possibles
		possible_dicts = [MATERIAL_DICT, "Hole", "StraitCut", "Pocket"]

		# Cherche le premier dictionnaire existant dans l'entité
		dict_name = possible_dicts.find { |d| entity.attribute_dictionary(d) }
		return nil unless dict_name

		if key.nil? || key == ""
			dict_name          # retourne le nom du dictionnaire trouvé
		else
			entity.get_attribute(dict_name, key)
		end
	end

	def self.fixHtmlFile(html_content,plugin_dir)
		css_path = "file:///" + File.join(plugin_dir, 'css', 'Sketchup.css').gsub("\\", "/")
		jquery_ui_path = "file:///" + File.join(plugin_dir, 'js', 'jquery-ui.css').gsub("\\", "/")
		jquery_js_path = "file:///" + File.join(plugin_dir, 'js/external/jquery/','jquery.js').gsub("\\", "/")
		jquery_uijs_path = "file:///" + File.join(plugin_dir, 'js', 'jquery-ui.js').gsub("\\", "/")
		# Modifier le HTML pour utiliser ces chemins
		html_content.gsub!("../css/Sketchup.css", css_path)
		html_content.gsub!("../js/jquery-ui.css", jquery_ui_path)
		html_content.gsub!("../js/external/jquery/jquery.js", jquery_js_path)
		html_content.gsub!("../js/jquery-ui.js", jquery_uijs_path)
		html_content
	end

	def self.findMaterial
		group_Material = Sketchup.active_model.entities.grep(Sketchup::Group).find { |cp| cp.attribute_dictionaries && cp.attribute_dictionaries[MATERIAL_DICT] }
		return group_Material
	end

	def self.getSafeHeight
		group_Material = findMaterial
		if group_Material != nil
			return group_Material.get_attribute(MATERIAL_DICT, "safeHeight")
		else
			return nil
		end
	end

	def self.material_type
		group_Material = findMaterial
		if group_Material != nil
			return group_Material.get_attribute(MATERIAL_DICT, "material_type")
		else
			return nil
		end
	end

	def self.material_Height
		group_Material = findMaterial
		if group_Material != nil
			return group_Material.get_attribute(MATERIAL_DICT, "material_Height")
		else
			return nil
		end
	end

	class Material
      @material_type = "Acrylic"
      @safeHeight = 5

	  # ------------------------
	  # Sauvegarde d'un groupe
	  # ------------------------
	  def self.save_group_data(group)
		group_data = {}

		arcsObj = {}
		curveObj = {}

		edges = []
		faces = []
		components = []
		groups = []
		curves = []
		arcs = []
		
#		group.set_attribute(MATERIAL_DICT, "safeHeight", @safeHeight)
#		group.set_attribute(MATERIAL_DICT, "material_type", @material_type)

		sousgroups = Sketchup.active_model.entities.grep(Sketchup::Group)
		path_obj_list = sousgroups.select { |g| GNTools::Paths.isGroupObj(g) }
#		path_obj_list.each{|sousgroup| sousgroup.visible = false}

		group.entities.each do |entity|
		  if entity.is_a?(Sketchup::Edge) && entity.curve &&
			 (entity.curve.is_a?(Sketchup::ArcCurve) || entity.curve.is_a?(Sketchup::Curve))
			acurve = entity.curve
			if acurve.is_a?(Sketchup::ArcCurve)
			  unless arcsObj.key?(acurve.persistent_id)
				arcsObj[acurve.persistent_id] = acurve
				arcs << {
				  center: acurve.center.to_a,
				  circular: acurve.circular?,
				  radius: acurve.radius,
				  start_angle: acurve.start_angle,
				  end_angle: acurve.end_angle,
				  normal: acurve.normal.to_a,
				  xaxis: acurve.xaxis.to_a
				}
			  end
			elsif acurve.is_a?(Sketchup::Curve)
			  unless curveObj.key?(acurve.persistent_id)
				curveObj[acurve.persistent_id] = acurve
				acurve.edges.each do |edge|
				  curves << {
					start: edge.start.position.to_a,
					finish: edge.end.position.to_a
				  }
				end
			  end
			end
		  elsif entity.is_a?(Sketchup::Edge)
			edges << { start: entity.start.position.to_a, finish: entity.end.position.to_a }
		  elsif entity.is_a?(Sketchup::Face)
			faces << { vertices: entity.vertices.map { |v| v.position.to_a } }
		  elsif entity.is_a?(Sketchup::ComponentInstance)
			components << { definition_name: entity.definition.name }
		  elsif entity.is_a?(Sketchup::Group)
			if GNTools::Paths::isGroupObj(entity) == nil
				groups << self.save_group_data(entity) # récursif
			end
		  end
		end

		group_data["edges"] = edges
		group_data["faces"] = faces
		group_data["components"] = components
		group_data["groups"] = groups
		group_data["arcs"] = arcs
		group_data["curves"] = curves

		json_data = JSON.generate(group_data)

		group.set_attribute(MATERIAL_DICT, "groupData", JSON.generate(json_data))
		# Sauvegarde l’état original une seule fois
		unless group.get_attribute(MATERIAL_DICT, "originalData")
			group.set_attribute(MATERIAL_DICT, "originalData", json_data)
		end

#		path_obj_list.each{|sousgroup| sousgroup.visible = true}

		group_data
	  end

  	  def self.clear_all_geometry_except_paths(group)
	    group.entities.each do |e|
		  if e.is_a?(Sketchup::Group)
		    # On laisse intacts les groupes PATH
		    next if GNTools::Paths.isGroupObj(e)
		    # Nettoyer récursivement
		    clear_all_geometry_except_paths(e)
		  elsif e.is_a?(Sketchup::Face) || e.is_a?(Sketchup::Edge)
		    e.erase!
		  end
	    end
	  end

	  def self.create_from_json(group,json)
	    # Reconstruire comme dans "create_group_from_data" mais sans recréer un nouveau group
	    group_data = JSON.parse(json)
	    self.build_group_entities(group.entities, group_data)
	    group.set_attribute(MATERIAL_DICT, "groupData", json)
	  end


	  def self.restore_original(group)
		  original_json = group.get_attribute(MATERIAL_DICT, "originalData")
		  return nil unless original_json

		  sousgroups = group.entities.grep(Sketchup::Group)
		  path_obj_list = sousgroups.select { |g| GNTools::Paths.isGroupObj(g) }
		  path_obj_list.each{|sousgroup| sousgroup.visible = false}
#		  Sketchup.active_model.start_operation(GNTools::traduire("Restore Original"), true)

		  # Supprimer la géométrie actuelle
#		  group.entities.clear!
		  clear_all_geometry_except_paths(group)


		  # Reconstruire comme dans "create_group_from_data" mais sans recréer un nouveau group
		  group_data = JSON.parse(original_json)
		  self.build_group_entities(group.entities, group_data)

		  # Mettre groupData = originalData (réinitialisation)
		  group.set_attribute(MATERIAL_DICT, "groupData", original_json)
#		  Sketchup.active_model.commit_operation()
		  path_obj_list.each{|sousgroup| sousgroup.visible = true}
		  group
	  end

	  # ------------------------
	  # Création d'un groupe depuis données
	  # ------------------------
	  def self.create_group_from_data(source_group)
		group_data_json = source_group.get_attribute(MATERIAL_DICT, "groupData")
		return nil unless group_data_json

		group_data = JSON.parse(group_data_json)
		new_group = Sketchup.active_model.entities.add_group
		self.build_group_entities(new_group.entities, group_data)

		# Copier aussi les attributs de matériau s’ils existent
		mat_type       = source_group.get_attribute(MATERIAL_DICT, "material_type")
		materialHeight = source_group.get_attribute(MATERIAL_DICT, "material_Height")
		
		new_group.set_attribute(MATERIAL_DICT, "safeHeight", safe_height)
		new_group.set_attribute(MATERIAL_DICT, "material_type", mat_type)
		new_group.set_attribute(MATERIAL_DICT, "material_Height",materialHeight)
		new_group.set_attribute(MATERIAL_DICT, "groupData", group_data_json)
		material_type = source_group.get_attribute(MATERIAL_DICT, "material_type")
		safeHeight = source_group.get_attribute(MATERIAL_DICT, "safeHeight")
		materialHeight = source_group.get_attribute(MATERIAL_DICT, "material_Height")
		new_group.set_attribute(MATERIAL_DICT, "safeHeight", @safeHeight)
		new_group.set_attribute(MATERIAL_DICT, "material_type", @material_type)
		new_group.set_attribute(MATERIAL_DICT, "material_Height",@materialHeight)

		new_group
	  end

	  # ------------------------
	  # Construction récursive
	  # ------------------------
	  def self.build_group_entities(entities, group_data)
		group_data["edges"].each do |edge|
		  entities.add_line(Geom::Point3d.new(edge["start"]),
							Geom::Point3d.new(edge["finish"]))
		end

		group_data["faces"].each do |face|
		  pts = face["vertices"].map { |v| Geom::Point3d.new(v) }
		  entities.add_face(pts) rescue nil
		end

		group_data["arcs"].each do |arc|
		  center = Geom::Point3d.new(arc["center"])
		  normal = Geom::Vector3d.new(arc["normal"])
		  xaxis  = Geom::Vector3d.new(arc["xaxis"])
		  entities.add_arc(center, xaxis, normal, arc["radius"],
						   arc["start_angle"], arc["end_angle"])
		end

		unless group_data["curves"].empty?
		  curve_points = []
		  group_data["curves"].each do |curve|
			curve_points << Geom::Point3d.new(curve["start"])
			curve_points << Geom::Point3d.new(curve["finish"])
		  end
		  entities.add_curve(curve_points)
		end

		group_data["groups"].each do |subgroup_data|
		  sub_group = entities.add_group
		  self.build_group_entities(sub_group.entities, subgroup_data)
		end

		group_data["components"].each do |comp|
		  definition = Sketchup.active_model.definitions[comp["definition_name"]]
		  entities.add_instance(definition, Geom::Transformation.new) if definition
		end
	  end
	end

	class MaterialDialog
		def initialize(group = nil)
			model     = Sketchup.active_model
			selection = model.selection
			entities  = model.entities

			@title = "Material Settings"
			@undoRedoName = ""
			@undoRedoDepth = -1
			
			@viewMode = "current"   # "original", "current", "path", "simulation"
			
			# -----------------------------
			# 1. Déterminer le groupe cible
			# -----------------------------
			if group
				# Si on a passé un groupe en paramètre
				@group = group
			elsif selection.empty?
				# Aucune sélection → créer un nouveau groupe vide
				@group = entities.add_group
			elsif selection.length == 1 && selection.first.is_a?(Sketchup::Group)
				# Sélection = 1 seul groupe
				@group = selection.first
			else
				# Sélection = plusieurs entités ou une seule non-group
				@group = entities.add_group(selection.to_a)
			end


			show_dialog
		end
		
		def dialog_ready
			dict_type = GNTools.is_cnc_group(@group)
			if dict_type == MATERIAL_DICT
				Sketchup.active_model.start_operation(GNTools::traduire("Edit Material"), true)
				@undoRedoName = GNTools::OperationTracker.current_op
				@undoRedoDepth = GNTools::OperationTracker.stack_depth
				# Cas : déjà un groupe CNC/Material → on recharge les données
				@material_type  = @group.get_attribute(MATERIAL_DICT, "material_type")
				@safeHeight     = @group.get_attribute(MATERIAL_DICT, "safeHeight")
				@materialHeight = @group.get_attribute(MATERIAL_DICT, "material_Height")
				unless @group.get_attribute(MATERIAL_DICT, "originalData")
					@group.delete_attribute(MATERIAL_DICT, "originalData")
				end
				Material::save_group_data(@group)
			else
				Sketchup.active_model.start_operation(GNTools::traduire("Create Material"), true)
				@undoRedoName = GNTools::OperationTracker.current_op
				@undoRedoDepth = GNTools::OperationTracker.stack_depth
				# Cas : pas CNC, ou CNC/Autre → créer/convertir en CNC/Material
				if dict_type && dict_type != MATERIAL_DICT
					# C’était un CNC/Autre → on crée un nouveau groupe vide pour isoler
					@group = entities.add_group
				end
				@group.name = "Material CNC"
				@material_type = "Acrylic"
				@safeHeight    = 5
				@materialHeight = 4
				@group.set_attribute(MATERIAL_DICT, "safeHeight", @safeHeight)
				@group.set_attribute(MATERIAL_DICT, "material_type", @material_type)
				@group.set_attribute(MATERIAL_DICT, "material_Height",@materialHeight)
				unless @group.get_attribute(MATERIAL_DICT, "originalData")
					@group.delete_attribute(MATERIAL_DICT, "originalData")
				end
				Material::save_group_data(@group)
			end
			@newData = [@material_type, @safeHeight, @materialHeight]

			self.update_dialog
			attach_selection_observer
		end
	
		def show_dialog
			if @dialog && @dialog.visible?
				self.update_dialog
				@dialog.bring_to_front
			else
				# Attach content and callbacks when showing the dialog,
				# not when creating it, to be able to use the same dialog again.
				@dialog ||= self.create_dialog
				@dialog.add_action_callback("ready") { |action_context|
					self.dialog_ready
					nil
				}
				# set to model only
				@dialog.add_action_callback("accept") { |action_context, value|
					@material_type = @newData[0]
					@safeHeight = @newData[1]
					@materialHeight = @newData[2]
					@group.set_attribute(MATERIAL_DICT, "safeHeight", @safeHeight)
					@group.set_attribute(MATERIAL_DICT, "material_type", @material_type)
					@group.set_attribute(MATERIAL_DICT, "material_Height",@materialHeight)
					if @undoRedoName == GNTools::OperationTracker.current_op and @undoRedoDepth == GNTools::OperationTracker.stack_depth
						Sketchup.active_model.commit_operation()
					end
					close_dialog
					Sketchup.active_model.tools.pop_tool
					nil
				}
				@dialog.add_action_callback("cancel") { |action_context, value|
					if @undoRedoName == GNTools::OperationTracker.current_op and @undoRedoDepth == GNTools::OperationTracker.stack_depth
						Sketchup.active_model.abort_operation()
					end
					close_dialog
					Sketchup.active_model.tools.pop_tool
					nil
				}
				@dialog.add_action_callback("newValue") { |action_context, valueName, value|
					if valueName == "material_type"
						@newData[0] = value["material_type"]
					elsif valueName == "safeHeight"
						@newData[1] = value["safeHeight"]
					elsif valueName == "material_Height"
						@newData[2] = value["material_Height"]
					end
					nil
				}
				@dialog.add_action_callback("applyViewMode") { |action_context, mode|
					self.applyViewMode(mode)
					nil
				}
				@dialog.set_size(470,365)
				@dialog.show
			end
			
		end

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
#				Material::restore_original(@group)
				Material::clear_all_geometry_except_paths(@group)
				original_json = @group.get_attribute(MATERIAL_DICT, "originalData")
				return nil unless original_json
				Material::create_from_json(@group,original_json)
				# Créer une face dans le groupe
				face = @group.entities.add_face([0,0,0],[50.mm,0,0],[50.mm,50.mm,0],[0,50.mm,0])
				# Faire un pushpull
				face.pushpull(-10.mm)  # fonctionne parfaitement
#				path_obj_list.each do |obj|
#				  obj.createPath(@group)  # applique juste la géométrie
#				end
				Sketchup.active_model.active_view.refresh
			when "simulation"
				original_json = @group.get_attribute(MATERIAL_DICT, "originalData")
				return nil unless original_json
				Material::clear_all_geometry_except_paths(@group)
				sousgroup = @group.entities.add_group
				Material::create_from_json(sousgroup,original_json)
				until_index = path_obj_list.count
				puts "index = #{until_index}"
				puts "objet deleted #{@group.deleted?}"
				puts "objet #{@group}"
#				path_obj_list[0..until_index].each do |obj|		
#				  puts "objet #{@group} - #{obj}"			
#				  sousgroup.subtract(obj)
#				  Sketchup.active_model.active_view.refresh
#				end
				@group.entities.each {|entity| puts entity.inspect}
				sousgroup.explode
			end
		end

		def create_dialog
			html_file = File.join(PATH_UI, 'html', 'CNC_Material.html') # Use external HTML
			@@html_content = File.read(html_file)
			
			GNTools.fixHtmlFile(@@html_content,PATH_UI) # Chemin du plugin
						
			options = {
			  :dialog_title => @title,
			  :resizable => true,
			  :width => 470,
			  :height => 365,
			  :preferences_key => "example.htmldialog.materialinspector",
			  :style => UI::HtmlDialog::STYLE_UTILITY  # New feature!
			}
			dialog = UI::HtmlDialog.new(options)
			dialog.set_html(@@html_content) # Injecter le HTML modifié
#				dialog.set_file(html_file) # Can be set here.
			dialog.center # New feature!
			dialog.set_can_close { false }
			dialog
		end

		def update_dialog
			boundingbox = @group.bounds
			if @safeHeight < boundingbox.depth.to_mm
				@safeHeight = boundingbox.depth.to_mm + 5.mm
			end
			@materialHeight = boundingbox.depth.to_mm
			jsonStr = JSON.generate({
				'material_type' => @material_type,
				'safeHeight' => @safeHeight,
				'materialHeight' => @materialHeight,
				'width' => boundingbox.width,
				'height' => boundingbox.height,
				'depth' => boundingbox.depth,
			})
			scriptStr = "updateDialog(\'#{jsonStr}\')"
			@dialog.execute_script(scriptStr)
		end
		
		def close_dialog
			if @dialog
				if @undoRedoName == GNTools::OperationTracker.current_op and @undoRedoDepth == GNTools::OperationTracker.stack_depth
					Sketchup.active_model.abort_operation()
				end
				detach_selection_observer
				@dialog.set_can_close { true }
				@dialog.close
			end
		end
		# -----------------------
		#  Sélection Observer
		# -----------------------
		def attach_selection_observer
			@selection_observer = Class.new(Sketchup::SelectionObserver) do
				def initialize(dialog, target_group)
					@dialog = dialog
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
						@dialog.close_dialog
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