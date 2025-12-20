require 'sketchup.rb'
require 'json'

module GNTools

	class Material

	  CNC_DICT = "GN_CNC" unless const_defined?(:CNC_DICT)
      MATERIAL_HASH = "Material" unless const_defined?(:MATERIAL_HASH)
	
	  attr_reader :group
	
	  def initialize(group = nil)
		@group = group
	  end
	
	  def setGroup(group)
	    @group = group
	  end
	  
	  def self.isMaterial?(entity)
	    cnc_type(entity) == MATERIAL_HASH
	  end
	  
	  def isMaterial?
		return false unless @group
		self.class.isMaterial?(@group)
	  end

      def self.cnc_type(entity)
		return nil unless entity.is_a?(Sketchup::Group) || entity.is_a?(Sketchup::ComponentInstance)
        entity.get_attribute(CNC_DICT, "type")
      end

      def self.cnc?(entity)
        !!cnc_type(entity)
      end

	  def read
	    return default unless @group
	    json = @group.get_attribute(CNC_DICT, MATERIAL_HASH)
	    json ? JSON.parse(json) : default
	  end

      def write(data)
	    return unless @group
        @group.set_attribute(CNC_DICT, "type", MATERIAL_HASH)
        @group.set_attribute(CNC_DICT, MATERIAL_HASH, JSON.generate(data))
      end

      def update()
	    return unless block_given?
		return unless @group
        data = read()
        yield(data)
        write(data)
      end

	  def generate_gcode
		engine = GNTools::NewPaths::StrategyEngine.instance
		data = Marshal.load(Marshal.dump(read()))
		data.delete("toolpaths")
		engine.global_vars = data
		toolpaths = read["toolpaths"]
		toolpaths.map do |tp|
		  strategy = GNTools::NewPaths::ToolpathSchemas.get_strategy(tp[1]["type"])
		  puts tp[1],strategy["Name"]
		  engine.render(strategy["Name"], build_context(tp[1]))
		end.join("\n")
	  end

	  def build_context(toolpath)
		{
		  "material" => self,
		  "toolpath" => toolpath
		}
	  end

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
		
		unless group.get_attribute(CNC_DICT, "originalData")
		    group.delete_attribute(CNC_DICT, "originalData")
		  end
		
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
				  "center"       => acurve.center.to_a,
				  "circular"     => acurve.circular?,
				  "radius"       => acurve.radius,
				  "start_angle"  => acurve.start_angle,
				  "end_angle"    => acurve.end_angle,
				  "normal"       => acurve.normal.to_a,
				  "xaxis"        => acurve.xaxis.to_a
				}
			  end
			elsif acurve.is_a?(Sketchup::Curve)
			  unless curveObj.key?(acurve.persistent_id)
				curveObj[acurve.persistent_id] = acurve
				acurve.edges.each do |edge|
				  curves << {
					"start" => edge.start.position.to_a,
					"finish" => edge.end.position.to_a
				  }
				end
			  end
			end
		  elsif entity.is_a?(Sketchup::Edge)
			edges << { "start" => entity.start.position.to_a, "finish" => entity.end.position.to_a }
		  elsif entity.is_a?(Sketchup::Face)
			faces << { "vertices" => entity.vertices.map { |v| v.position.to_a } }
		  elsif entity.is_a?(Sketchup::ComponentInstance)
			components << { "definition_name" => entity.definition.name }
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

		group.set_attribute(CNC_DICT, "groupData", JSON.generate(json_data))
		# Sauvegarde l’état original une seule fois
		unless group.get_attribute(CNC_DICT, "originalData")
			group.set_attribute(CNC_DICT, "originalData", json_data)
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
	    group_data = JSON.parse(json)
	    self.build_group_entities(group.entities, group_data)
	    group.set_attribute(CNC_DICT, "groupData", json)
	  end


	  def self.restore_original(group)
		  original_json = group.get_attribute(CNC_DICT, "originalData")
		  return nil unless original_json

		  sousgroups = group.entities.grep(Sketchup::Group)
		  path_obj_list = sousgroups.select { |g| GNTools::Paths.isGroupObj(g) }
		  path_obj_list.each{|sousgroup| sousgroup.visible = false}
#		  Sketchup.active_model.start_operation(GNTools::traduire("Restore Original"), true)

		  # Supprimer la géométrie actuelle
#		  group.entities.clear!
		  clear_all_geometry_except_paths(group)

		  group_data = JSON.parse(original_json)
		  self.build_group_entities(group.entities, group_data)

		  # Mettre groupData = originalData (réinitialisation)
		  group.set_attribute(CNC_DICT, "groupData", original_json)
#		  Sketchup.active_model.commit_operation()
		  path_obj_list.each{|sousgroup| sousgroup.visible = true}
		  group
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
	  
	  # ----------------------------
	  # Valeurs par défaut
	  # ----------------------------
	  def default
		self.class.default
	  end

	  def self.default
		{
		  "material_type"  => "Acrylic",
		  "materialHeight" => 4.0,
		  "safeHeight"     => 5.0,
		  "z_zero"         => "top"
		}
	  end
	  
	  def self.materialTypes
	    {
	      "Acrylic" => "Acrylic",
	      "Aluminum" => "Aluminum",
	      "Birch_Plywood" => "Birch Plywood",
	      "Cherry_Plywood" => "Cherry Plywood"
	    }
	  end
	  
	  def [](k)
        read[k]
      end

      def []=(k, v)
        update do |d|
          d[k] = v
        end
      end
	  	  
	end

	def self.findMaterial
		group_Material = Sketchup.active_model.entities.grep(Sketchup::Group).find { |cp| cp.attribute_dictionaries && cp.attribute_dictionaries[Material::CNC_DICT] }
		return group_Material
	end

	def self.getSafeHeight
		group_Material = findMaterial
		if group_Material != nil
			return group_Material.get_attribute(Material::CNC_DICT, "safeHeight")
		else
			return nil
		end
	end

	def self.material_type
		group_Material = findMaterial
		if group_Material != nil
			return group_Material.get_attribute(Material::CNC_DICT, "material_type")
		else
			return nil
		end
	end

	def self.material_Height
		group_Material = findMaterial
		if group_Material != nil
			return group_Material.get_attribute(Material::CNC_DICT, "material_Height")
		else
			return nil
		end
	end
end #module GNTools