require 'sketchup.rb'
require 'json'

module GNTools

  class CNCData

    CNC_DICT = "GN_CNC" unless const_defined?(:CNC_DICT)

    attr_reader :group, :temp_hash

    # -------------------------------------------------
    # Init
    # -------------------------------------------------
    def initialize(group = nil)
      @group     = group
	  if @group
        @temp_hash = nil
	  else
        @temp_hash = {}
	  end
    end

    # -------------------------------------------------
    # Mode
    # -------------------------------------------------
    def temp?
      !!@temp_hash
    end

    # -------------------------------------------------
    # Root read
    # -------------------------------------------------
    def read
      if temp?
        @temp_hash
      else
        dict = @group.attribute_dictionary(CNC_DICT, false)
        hash = {}
		if dict
			dict.each_pair do |k, v|
			  hash[k] = JSON.parse(v) rescue v
			end
		else
		  nil
		end
        hash
      end
    end

    # -------------------------------------------------
    # Root write
    # -------------------------------------------------
    def write(root_hash)
      if temp?
        @temp_hash.replace(root_hash)
      else
        dict = @group.attribute_dictionary(CNC_DICT, true)
        root_hash.each do |k, v|
          dict[k] = JSON.generate(v)
        end
      end
    end

    # -------------------------------------------------
    # Root update
    # -------------------------------------------------
    def update
      return unless block_given?
      root = read
      yield(root)
      write(root)
    end

    # -------------------------------------------------
    # Access sub-structure
    # -------------------------------------------------
	def [](key)
	  return nil unless key

	  root = read

	  # Accès profond : "Material.safeHeight"
	  if key.is_a?(String) && key.include?(".")
		cur = root
		key.split(".").each do |k|
		  return nil unless cur.is_a?(Hash)
		  cur = cur[k]
		end
		return cur
	  end

	  # Accès simple
	  root[key]
	end

	def []=(key, value)
	  return unless key

	  update do |root|
		# Accès profond
		if key.is_a?(String) && key.include?(".")
		  keys = key.split(".")
		  last = keys.pop

		  cur = root
		  keys.each do |k|
			cur[k] ||= {}
			cur = cur[k]
		  end

		  cur[last] = value
		else
		  root[key] = value
		end
	  end
	end

	# Vérifie l’existence d’une clé
	# - key?("Material")
	# - key?("Material", "safeHeight")
	def key?(scope = nil, key = nil)
	  root = read

	  if key
		h = root[scope]
		return false unless h.is_a?(Hash)
		h.key?(key)
	  else
		root.key?(scope)
	  end
	end

	# Vérifie un chemin :
	# - exist?("Material")
	# - exist?("Material.safeHeight")
	# - exist?("Toolpaths.1234.points")
	def exist?(path)
	  return false unless path.is_a?(String) && !path.empty?

	  root = read

	  # Cas simple : root
	  unless path.include?(".")
		return root.key?(path)
	  end

	  cur = root
	  path.split(".").each do |k|
		return false unless cur.is_a?(Hash)
		return false unless cur.key?(k)
		cur = cur[k]
	  end

	  true
	end
	
    # -------------------------------------------------
    # TEMP MODE
    # -------------------------------------------------
    def set_as_temp
      return if temp?
      @temp_hash = Marshal.load(Marshal.dump(read))
      self
    end

	def setGroup(group = nil,saveTo = false)
	  @group = group
	  if saveTo
		commit!
	  end
	end

    def commit!
      return unless temp?
	  return unless @group
      dict = @group.attribute_dictionary(CNC_DICT, true)
      @temp_hash.each do |k, v|
        dict[k] = JSON.generate(v)
      end
      @temp_hash = nil
      self
    end

    def revert!
	  if @group
        @temp_hash = nil
	  else
        @temp_hash = {}
	  end
      self
    end

	def generate_gcode(tp_id = nil)
	  engine = GNTools::NewPaths::StrategyEngine.instance
	  data = Marshal.load(Marshal.dump(read()))
	  engine.global_vars = data["Material"]
	  toolpaths = data["Toolpaths"]
	  toolpaths.map do |tp|
		if (tp_id == nil) or (tp[0] == tp_id)
		  strategy = GNTools::NewPaths::ToolpathSchemas.get_strategy(tp[1]["type"])
#		  puts tp[1],strategy["Name"]
		  engine.render(strategy["Name"], build_context(tp[1]))
		end
	  end.join("\n")
	end

	def build_context(toolpath)
	  {
	    "material" => self,
	    "Toolpath" => toolpath
	  }
	end

    def hide_Material()
	  return unless @group
	  return unless exist?("OriginalData")

	  clear_drawn_entities()
	  ensure_placeholder_at(Geom::Point3d.new(0,0,0))

#	  # Calculer une position moyenne pour placer les placeholders si invalides
#	  tp = collection.toolpaths.first
#	  if tp
#	    first_pt = tp.points.first
#	    placeholder_pos = first_pt ? first_pt.position : Geom::Point3d.new(0,0,0)
#	  else
#	    placeholder_pos = Geom::Point3d.new(0,0,0)
#	  end
#	  self.ensure_placeholder_at(placeholder_pos)

#	  tpvalide = false

#	  if tpvalide
#	    self.remove_placeholder(group)
#	  end
    end

	def show_Material()
	  return unless @group
	  return unless exist?("OriginalData")

	  # Nettoyage avant reconstruction
	  clear_drawn_entities

	  build_group_entities(@group.entities, read["OriginalData"])
	  remove_placeholder
	end

    def ensure_placeholder_at(position)
	  ent = @group.entities

	  cp = ent.find { |e|
	    e.is_a?(Sketchup::ConstructionPoint) &&
	    e.get_attribute("GNTP", "placeholder")
	  }

	  if cp
	    ent.erase_entities(cp)
	  end
	  cp = ent.add_cpoint(position)
	  cp.set_attribute("GNTP", "placeholder", true)
	  cp.hidden = true

	  cp
    end

    def remove_placeholder()
	  to_delete = []

	  @group.entities.each do |e|
	    next unless e.is_a?(Sketchup::ConstructionPoint)
	    next unless e.get_attribute("GNTP", "placeholder")
	    to_delete << e
	  end

	  @group.entities.erase_entities(to_delete) unless to_delete.empty?
    end
	  
    def clear_drawn_entities()
	  to_delete = []
	  if @group
	    @group.entities.each do |e|
	      next if e.is_a?(Sketchup::ConstructionPoint) &&
		     e.get_attribute("GNTP", "placeholder")
	      to_delete << e
	    end

	    group.entities.erase_entities(to_delete) unless to_delete.empty?
      end
	end

    # ------------------------
    # Construction récursive
    # ------------------------
    def build_group_entities(entities, group_data)
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
	    build_group_entities(sub_group.entities, subgroup_data)
	  end

	  group_data["components"].each do |comp|
	    definition = Sketchup.active_model.definitions[comp["definition_name"]]
	    entities.add_instance(definition, Geom::Transformation.new) if definition
	  end
    end
	  
    # -------------------------------------------------
    # Export
    # -------------------------------------------------
    def to_hash
      Marshal.load(Marshal.dump(read))
    end

    def to_json(*args)
      JSON.pretty_generate(to_hash, *args)
    end

  end
  
  
	class Material

	  CNC_DICT = "GN_CNC" unless const_defined?(:CNC_DICT)
      MATERIAL_HASH = "Material" unless const_defined?(:MATERIAL_HASH)
	
	  attr_reader :group, :temp_hash
	
	  def initialize(group = nil, temp_hash = nil)
		@group = group
		@temp_hash = temp_hash
	  end
	  
	  # Permet de définir soit un group, soit un hash temporaire
	  def set_source(group: nil, temp_hash: nil)
		@group = group
		@temp_hash = temp_hash
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
	    if @temp_hash
		  @temp_hash
		elsif @group
		  dict = @group.attribute_dictionary(CNC_DICT, true)
		  hash = {}
		  dict.each_pair { |k,v| hash[k] = JSON.parse(v) rescue v }		  
		else
		  {}
		end
	  end

      def write(key=nil,data)
		if @temp_hash
		  if key
			@temp_hash[key] = data
		  else
			@temp_hash.replace(data)
		  end
		elsif @group
		  dict = @group.attribute_dictionary(CNC_DICT, true)
		  if key
			dict[key] = JSON.generate(data)
		  else
			data.each { |k,v| dict[k] = JSON.generate(v) }
		  end
		end
      end

      def update(key=nil)
		return unless block_given?
		root = read
		if key
		  sub = root[key]
		  sub = {} unless sub.is_a?(Hash)
		  yield(sub)
		  root[key] = sub
		else
		  yield(root)
		end
		write(key, root)
      end

	  def clone_to_temp
	    return unless @group

	    if @temp_hash
		  # vider le hash existant et le remplir avec les données du groupe
		  @temp_hash.clear
		  @temp_hash.merge!(read)
	    else
		  # créer un nouveau hash si nécessaire
		  @temp_hash = Marshal.load(Marshal.dump(read))
	    end
	  end

	  def clone_to_group
	    return unless @group && @temp_hash
		puts @temp_hash

	    dict = @group.attribute_dictionary(CNC_DICT, true)
	    @temp_hash.each do |k, v|
		  dict[k] = JSON.generate(v)   # stocke chaque sous-dictionnaire/valeur comme JSON
	    end

	    # éventuellement mettre le type
	    dict["type"] ||= "Material"
	  end

	  def full_attributes
		return {} unless @group
		result = {}

		# Parcours toutes les attribute_dictionaries
		if @group.attribute_dictionaries
		  @group.attribute_dictionaries.each do |dict|
			if CNC_DICT == dict.name
			  result = {}
			  dict.each_pair do |k,v|
			    result[k] = v
			  end
			end
		  end
		end
		result
	  end


	  def generate_gcode(tp_id = nil)
		engine = GNTools::NewPaths::StrategyEngine.instance
		data = Marshal.load(Marshal.dump(read()))
		data.delete("Toolpaths")
		engine.global_vars = data
		toolpaths = read["Toolpaths"]
		toolpaths.map do |tp|
		  if (tp_id == nil) or (tp[0] == tp_id)
		    strategy = GNTools::NewPaths::ToolpathSchemas.get_strategy(tp[1]["type"])
#		    puts tp[1],strategy["Name"]
		    engine.render(strategy["Name"], build_context(tp[1]))
		  end
		end.join("\n")
	  end
	  
	  
	  def each_toolpath
        data = read
        return enum_for(:each_toolpath) unless block_given?
        return unless data["Toolpaths"]

        data["Toolpaths"].each do |tp_id, tp|
          yield(tp_id, tp)
        end
      end

	  def build_context(toolpath)
		{
		  "material" => self,
		  "Toolpath" => toolpath
		}
	  end


	  def self.get_group_data(group)
		group_data = {}

		arcsObj = {}
		curveObj = {}

		edges = []
		faces = []
		components = []
		groups = []
		curves = []
		arcs = []
		
		unless group.get_attribute(CNC_DICT, "OriginalData")
		    group.delete_attribute(CNC_DICT, "OriginalData")
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
				groups << self.get_group_data(entity) # récursif
			end
		  end
		end

		group_data["edges"] = edges
		group_data["faces"] = faces
		group_data["components"] = components
		group_data["groups"] = groups
		group_data["arcs"] = arcs
		group_data["curves"] = curves

		group_data
	  end

	  # ------------------------
	  # Sauvegarde d'un groupe
	  # ------------------------
	  def self.save_group_data(group)
		group_data = self.get_group_data(group)
		json_data = JSON.generate(group_data)

		group.set_attribute(CNC_DICT, "groupData", JSON.generate(json_data))
		# Sauvegarde l’état original une seule fois
		unless group.get_attribute(CNC_DICT, "OriginalData")
			group.set_attribute(CNC_DICT, "OriginalData", json_data)
		end

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
		  original_json = group.get_attribute(CNC_DICT, "OriginalData")
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
	  
	  def self.group_entities(group,collection)
	    return unless group
	    self.clear_drawn_entities(group)
	    # Calculer une position moyenne pour placer les placeholders si invalides
	    tp = collection.toolpaths.first
	    if tp
		  first_pt = tp.points.first
		  placeholder_pos = first_pt ? first_pt.position : Geom::Point3d.new(0,0,0)
	    else
	 	  placeholder_pos = Geom::Point3d.new(0,0,0)
	    end
	    self.ensure_placeholder_at(group,placeholder_pos)

	    tpvalide = false

	    if tpvalide
		  self.remove_placeholder(group)
	    end
	  end

	  def self.show_toolpath(group,tp)
	    ent = group.entities

	    pts = tp.points.map(&:position)
	    return if pts.empty?

	    # 1 point → CPoint
	    if pts.length == 1
		  ent.add_cpoint(pts[0])
		  return
	    end

	    # 2+ points → polyline
	    pts.each_cons(2) do |a, b|
		  ent.add_line(a, b)
	    end
	  end
  
	  def self.ensure_placeholder_at(group,position)
	    ent = group.entities

	    cp = ent.find { |e|
		  e.is_a?(Sketchup::ConstructionPoint) &&
		  e.get_attribute("GNTP", "placeholder")
	    }

	    if cp
		  ent.erase_entities(cp)
	    end
	    cp = ent.add_cpoint(position)
	    cp.set_attribute("GNTP", "placeholder", true)
	    cp.hidden = true

	    cp
	  end

	  def self.remove_placeholder(group)
	    to_delete = []

	    group.entities.each do |e|
		  next unless e.is_a?(Sketchup::ConstructionPoint)
		  next unless e.get_attribute("GNTP", "placeholder")
		  to_delete << e
	    end

	    group.entities.erase_entities(to_delete) unless to_delete.empty?
	  end

	  def self.clear_drawn_entities(group)
	    to_delete = []

	    group.entities.each do |e|
		  next if e.is_a?(Sketchup::ConstructionPoint) &&
			 e.get_attribute("GNTP", "placeholder")
		  to_delete << e
	    end

	    group.entities.erase_entities(to_delete) unless to_delete.empty?
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