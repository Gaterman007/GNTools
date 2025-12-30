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

	def self.cnc?(group)
	  dict = group.attribute_dictionary(CNC_DICT, false)
	  if dict
		return true
	  end
	  return false
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
	  engine.global_vars = data
	  toolpaths = data["Toolpaths"]
	  toolpaths.map do |tp|
		if (tp_id == nil) or (tp[0] == tp_id)
		  strategy = GNTools::NewPaths::ToolpathSchemas.instance.get_strategy(tp[1]["type"])
#		  puts tp[1],strategy["Name"]
		  engine.render(strategy["Name"], tp[0])
		end
	  end.join("\n")
	end

    def hide_Material()
	  return unless @group
	  return unless exist?("OriginalData")

	  GNTools.with_preview_operation("Hide Material") do
	    clear_drawn_entities()
	    ensure_placeholder_at(Geom::Point3d.new(0,0,0))
	  end
    end

	def show_Material()
	  return unless @group
	  return unless exist?("OriginalData")

	  GNTools.with_preview_operation("Show Material") do

	    # Nettoyage avant reconstruction
	    clear_drawn_entities

	    build_group_entities(@group.entities, read["OriginalData"])
	    remove_placeholder
	  end
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
	
	def get_group_data(group)
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
		  faces << {
			"vertices" => entity.vertices.map { |v| v.position.to_a },
			"normal"   => entity.normal.to_a
		  }
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
    # Construction récursive
    # ------------------------
    def build_group_entities(entities, group_data)
	  group_data["edges"].each do |edge|
	    entities.add_line(Geom::Point3d.new(edge["start"]),
					Geom::Point3d.new(edge["finish"]))
	  end

	  group_data["faces"].each do |face_data|
	    pts = face_data["vertices"].map { |v| Geom::Point3d.new(v) }

	    face = entities.add_face(pts)
	    next unless face && face.valid?

	    original_normal = Geom::Vector3d.new(face_data["normal"])

	    # Si la normale reconstruite est inversée → on retourne la face
	    if face.normal.dot(original_normal) < 0
		  face.reverse!
	    end
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

  end
  
  def self.findMaterial
	group_Material = Sketchup.active_model.entities.grep(Sketchup::Group).find { |cp| cp.attribute_dictionaries && cp.attribute_dictionaries[Material::CNC_DICT] }
	return group_Material
  end

  def self.getSafeHeight
	group_Material = findMaterial
	if group_Material != nil
	  return group_Material.get_attribute(CNCData::CNC_DICT, "safeHeight")
	else
	  return nil
	end
  end

  def self.material_type
	group_Material = findMaterial
	if group_Material != nil
	  return group_Material.get_attribute(CNCData::CNC_DICT, "material_type")
	else
	  return nil
	end
  end

  def self.material_Height
	group_Material = findMaterial
	if group_Material != nil
	  return group_Material.get_attribute(CNCData::CNC_DICT, "material_Height")
	else
	  return nil
	end
  end
end #module GNTools