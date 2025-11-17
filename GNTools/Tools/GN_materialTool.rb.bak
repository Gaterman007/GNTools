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
			groups << self.save_group_data(entity) # récursif
		  end
		end

		group_data["edges"] = edges
		group_data["faces"] = faces
		group_data["components"] = components
		group_data["groups"] = groups
		group_data["arcs"] = arcs
		group_data["curves"] = curves

		group.set_attribute(MATERIAL_DICT, "groupData", JSON.generate(group_data))
		group_data
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
		mat_type    = source_group.get_attribute(MATERIAL_DICT, "material_type")
		new_group.set_attribute(MATERIAL_DICT, "safeHeight", safe_height)
		new_group.set_attribute(MATERIAL_DICT, "material_type", mat_type)
		new_group.set_attribute(MATERIAL_DICT, "groupData", group_data_json)
		material_type = source_group.get_attribute(MATERIAL_DICT, "material_type")
		safeHeight = source_group.get_attribute(MATERIAL_DICT, "safeHeight")
		new_group.set_attribute(MATERIAL_DICT, "safeHeight", @safeHeight)
		new_group.set_attribute(MATERIAL_DICT, "material_type", @material_type)
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

			# -----------------------------
			# 2. Vérifier le type CNC
			# -----------------------------
			dict_type = GNTools.is_cnc_group(@group)

			if dict_type == MATERIAL_DICT
				# Cas : déjà un groupe CNC/Material → on recharge les données
				@material_type = @group.get_attribute(MATERIAL_DICT, "material_type")
				@safeHeight    = @group.get_attribute(MATERIAL_DICT, "safeHeight")

			else
				# Cas : pas CNC, ou CNC/Autre → créer/convertir en CNC/Material
				if dict_type && dict_type != MATERIAL_DICT
					# C’était un CNC/Autre → on crée un nouveau groupe vide pour isoler
					@group = entities.add_group
				end

				@group.name = "Material CNC"
				@material_type = "Acrylic"
				@safeHeight    = 5
				@group.set_attribute(MATERIAL_DICT, "safeHeight", @safeHeight)
				@group.set_attribute(MATERIAL_DICT, "material_type", @material_type)
				Material::save_group_data(@group)
			end

			# -----------------------------
			# 3. Finalisation
			# -----------------------------
			@newData = [@material_type, @safeHeight]
			show_dialog
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
					self.update_dialog
					nil
				}
				# set to model only
				@dialog.add_action_callback("accept") { |action_context, value|
						@material_type = @newData[0]
						@safeHeight = @newData[1]
						@group.set_attribute(MATERIAL_DICT, "safeHeight", @safeHeight)
						@group.set_attribute(MATERIAL_DICT, "material_type", @material_type)
					close_dialog
					Sketchup.active_model.tools.pop_tool
					nil
				}
				@dialog.add_action_callback("cancel") { |action_context, value|
					close_dialog
					Sketchup.active_model.tools.pop_tool
					nil
				}
				@dialog.add_action_callback("newValue") { |action_context, valueName, value|
					if valueName == "material_type"
						@newData[0] = value["material_type"]
					elsif valueName == "safeHeight"
						@newData[1] = value["safeHeight"]
					end
					nil
				}
				@dialog.set_size(460,305)
				@dialog.show
			end
			
		end

		def create_dialog
			html_file = File.join(PATH_UI, 'html', 'CNC_Material.html') # Use external HTML
			@@html_content = File.read(html_file)
			
			GNTools.fixHtmlFile(@@html_content,PATH_UI) # Chemin du plugin
						
			options = {
			  :dialog_title => @title,
			  :resizable => true,
			  :width => 460,
			  :height => 305,
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
			jsonStr = JSON.generate({
				'material_type' => @material_type,
				'safeHeight' => @safeHeight,
				'width' => 0.0,
				'height' => 0.0,
				'depth' => 0.0,
			})
			scriptStr = "updateDialog(\'#{jsonStr}\')"
			@dialog.execute_script(scriptStr)
		end
		
		def close_dialog
			if @dialog
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