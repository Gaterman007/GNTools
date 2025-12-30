module GNTools
  module NewPaths

    ##
    # visualisation des Toolpath (SketchUp).
    #
    class ToolpathPreview
	  # Dessiner une collection (un json)
	  DEFAULT = {
	    "Line" => {
		  "Toolpaths"   => <<~PREV,
			; --- Preview: Hole ---
			MOVE {CurrentTp.points[0].pos[0]} {CurrentTp.points[0].pos[1]} {Material.safeHeight}
			LINE {CurrentTp.points[0].pos[0]} {CurrentTp.points[0].pos[1]} {CurrentTp.points[0].pos[2]}
			CYLINDER {CurrentTp.points[0].pos[0]} {CurrentTp.points[0].pos[1]} {CurrentTp.metadata.holesize.Value} {CurrentTp.metadata.depth.Value}
		    {foreach p in CurrentTp.points}
			  LINE {p.pos[0]} {p.pos[1]} {CurrentTp.metadata.depth.Value}
		    {end}
		    MOVE {points[-1].x} {points[-1].y} {Material.safeHeight}
		  PREV
		  "Material"    => <<~PREV,
		    DRAW_CROIX {CurrentTp.points[0]}
		  PREV
		  "Simulation"  => <<~PREV,
		    DRAW_FACE {CurrentTp.points[0]} {CurrentTp.metadata.depth.Value}
		  PREV
		  "Original"    => <<~PREV,
		    DRAW_POLYLINE {points}
		  PREV
	    },
	    "Hole" => {
		  "Toolpaths"   => <<~PREV,
		    DRAW_CROIX {CurrentTp.points[0]} {CurrentTp.metadata.holesize.Value}
		  PREV
		  "Material"    => <<~PREV,
		    DRAW_CIRCLE {CurrentTp.points[0]} {CurrentTp.metadata.holesize.Value}
		  PREV
		  "Simulation"  => <<~PREV,
		    DRAW_CYLINDER {CurrentTp.points[0]} {CurrentTp.metadata.holesize.Value} {CurrentTp.metadata.depth.Value}
		  PREV
		  "Original"    => <<~PREV,
		    DRAW_POINT {CurrentTp.points[0]}
		  PREV
	    }
	  }
	  	  
	  attr_accessor:previews
	  attr_accessor :global_vars

      def self.instance
        @instance ||= new
      end
	  
      def initialize()
		@previews = load_all_previews
		@global_vars = {}
      end

	  def load_all_previews
	    base = Marshal.load(Marshal.dump(DEFAULT)) # duplication profonde
	    custom = load_custom_file
	    deep_merge(base, custom)
	  end

	  def deep_merge(hash1, hash2)
	    hash2.each do |k, v|
		  if v.is_a?(Hash) && hash1[k].is_a?(Hash)
		    hash1[k] = deep_merge(hash1[k], v)
		  else
		    hash1[k] = v
		  end
	    end
	    hash1
	  end
	  
      def load_custom_file
        file = File.join(GNTools::PATH_TOOLS, "Previews.custom")
        return {} unless File.exist?(file)

        text = File.read(file)
        parse_custom_previews(text)
      end

      # ============================================================
      # Sauvegarde
      # ============================================================
	  def save_custom_previews
	    file = File.join(GNTools::PATH_TOOLS, "Previews.custom")

	    File.open(file, "w") do |f|
		  @previews.each do |type, previews_hash|
		    previews_hash.each do |preview_name, text|
			  default_text = DEFAULT.dig(type, preview_name)
			  next if default_text && default_text == text
			  f.puts "[preview #{type}/#{preview_name}]"
			  f.puts text
			  f.puts
		    end
		  end
	    end
	  end

 	  def self.apply_preview_diff(diff_hash)
		
	    return unless diff_hash.is_a?(Hash)

	    diff_hash.each do |name, text|
		  if text.nil?
		    # suppression
		    self.instance.previews.delete(name)
		  else
		    # ajout ou override
		    self.instance.previews[name] = text
		  end
	    end

	    self.instance.save_custom_previews
	  end
	  
      # ============================================================
      # Parsing du fichier custom
      # ============================================================
	  # Exemple de header : [preview Hole/Material]
	  def parse_custom_previews(text)
	    h = {}
	    current_type = nil
	    current_preview = nil
	    buffer = []

	    text.each_line do |line|
		  if line =~ /^\[preview (.+?)\/(.+?)\]/
		    h[current_type] ||= {}
		    h[current_type][current_preview] = buffer.join if current_type && current_preview
		    current_type, current_preview = $1.strip, $2.strip
		    buffer = []
		  elsif current_type && current_preview
		    buffer << line
		  end
	    end

	    h[current_type] ||= {}
	    h[current_type][current_preview] = buffer.join if current_type && current_preview
	    h
	  end

	  def self.toJson
	  	JSON.generate(self.instance.previews)
	  end

	  def self.get_script(toolpath_type, preview_type)
	    self.instance.previews.dig(toolpath_type, preview_type) ||
	    self.instance.previews.dig(toolpath_type, "Material") || # fallback
	    self.instance.previews.dig("Line", "Material")           # fallback global
	  end
	  
	  def self.render(view, collection, type = "material",vars = nil)
	  
		puts "collection #{collection['Toolpaths']}"
#		@previews
	  	# Merge : global < local
		@vars = @global_vars.dup
		@vars.merge!(vars) if vars
		if collection["Toolpaths"]
		  collection["Toolpaths"].each do |name,toolpath|
			@toolpath = toolpath
			puts toolpath['type']
			@view = view
			@text = get_script(toolpath['type'], type).dup
			next unless @text
			process_foreach!
			process_if!
			process_vars!
			process_cmd!
		  end
		end
		case type
	    when "Toolpaths"
		  self.draw_toolpaths(view, collection["Toolpaths"])
	    when "Material"
		  self.draw_toolpaths(view, collection["Toolpaths"])
		  self.draw_material_outline(view, collection["Material"])
	    when "OriginalData"
		  self.draw_original_geometry(view, collection["OriginalData"])
	    when "Simulation"
		  self.draw_original_geometry(view, collection["OriginalData"])
		  self.draw_toolpaths(view, collection["Toolpaths"])
	    end
	  end

	  def self.process_cmd!
	    return unless @text
	    return unless @view
	    return unless @toolpath

	    @text.each_line do |line|
		  line.strip!
		  next if line.empty?
		  next if line.start_with?("#", ";")

		  tokens = line.split(/\s+/)
		  cmd = tokens.shift

		  case cmd
		  when "DRAW_CROIX"
		    process_draw_croix(tokens)

		  when "DRAW_OUTLINE"
		    process_draw_outline(tokens)

		  else
		    puts "[Preview] commande inconnue : #{cmd}"
		  end
	    end	  
	  end

	  def self.process_if!
	    @text.gsub!(/\{if (.+?)\}(.*?)\{end\}/m) do
		  condition = $1.strip
		  block = $2

		  result = eval_condition(condition)
		  result ? block : ""
	    end
	  end

	  def self.eval_condition(cond)
	    # Si c'est une comparaison : var > 0, x == y, etc.
	    if cond =~ /(.+?)\s*(==|!=|>=|<=|>|<)\s*(.+)/
		  left_expr  = $1.strip
		  operator   = $2
		  right_expr = $3.strip

		  left_val  = eval_in_schema(left_expr)
		  right_val = eval_in_schema(right_expr)

		  # conversion numérique si possible
		  left_val  = numeric_or_string(left_val)
		  right_val = numeric_or_string(right_val)

		  case operator
		  when "==" then left_val == right_val
		  when "!=" then left_val != right_val
		  when ">"  then left_val >  right_val
		  when "<"  then left_val <  right_val
		  when ">=" then left_val >= right_val
		  when "<=" then left_val <= right_val
		  else false
		  end

	    else
		  # Cas booléen simple : {if enabled}
		  val = eval_in_schema(cond)
		  boolize(val)
	    end
	  end

	  def self.numeric_or_string(v)
	    Float(v) rescue v
	  end

	  def self.boolize(v)
	    return true if v == true || v.to_s.downcase == "true" || v.to_s == "1"
	    return false
	  end

      # ============================================================
      # Traitement {foreach}
      # ============================================================
      def self.process_foreach!
        @text.gsub!(/\{foreach ([a-zA-Z0-9_]+) in ([a-zA-Z0-9_]+)\}(.*?)\{end\}/m) do
          item_name = $1
          array_name = $2
          block = $3
	
		  if @toolpath
			if array_name == "points"
			  point_array = @toolpath["points"]
			  point_array.map do |item|
			    b = block.dup
				b.gsub!(/\{#{item_name}\.x\}/, item.position.x.round(2).to_s)
				b.gsub!(/\{#{item_name}\.y\}/, item.position.y.round(2).to_s)
				b.gsub!(/\{#{item_name}\.z\}/, item.position.z.round(2).to_s)				
				b
			  end
			else
			  array = @toolpath["metadata"][array_name]
			  raise "Missing array #{array_name}" unless array.is_a?(Array)

			  array.map do |item|
			    b = block.dup
			    b.gsub!(/\{#{item_name}\}/, item.to_s)
			    if item.respond_to?(:x)
				  b.gsub!(/\{#{item_name}\.x\}/, item.x.round(2).to_s)
				  b.gsub!(/\{#{item_name}\.y\}/, item.y.round(2).to_s)
				  b.gsub!(/\{#{item_name}\.z\}/, item.z.round(2).to_s) if item.respond_to?(:z)
			    end
			    b
			  end
			end.join("\n")
		  end
        end
      end

      # ============================================================
      # Traitement des variables simples {var}
      # ============================================================
      def self.process_vars!
        @text.gsub!(/\{([a-zA-Z0-9_\.\[\]]+)\}/) do
          eval_in_schema($1)
        end
      end


      def self.eval_in_schema(expr)
		return expr unless @toolpath

	    # 0 — variables globales / locales
	    if @vars && @vars.key?(expr)
		  v = @vars[expr]
		  return v.is_a?(Numeric) ? v.round(2).to_s : v.to_s
	    end

	    # 1 — Séparer base et attribut (ex : "points[0]" + "x")
	    if expr.include?(".")
		  base, attr = expr.split(".", 2)
	    else
		  base = expr
		  attr = nil
	    end

	    # 2 — Détecter accès tableau : pts[0]
	    if base =~ /(\w+)\[(\d+)\]/
		  key   = $1
		  index = $2.to_i
		  # Cas spécial : points[]
		  if key == "points"
			pt = @toolpath["points"][index]["pos"]

			if attr # points[0].x / .y / .z
			  case attr
			  when "x" then return pt.x.round(2).to_s
			  when "y" then return pt.y.round(2).to_s
			  when "z" then return pt.z.round(2).to_s
			  else
				raise "Invalid attribute #{attr} for points[]"
			  end
			else
			  # points[0] sans . → full XYZ
			  return pt.position_to_string
			end
		  end

		  # Autres tableaux (ex : feeds[1], speeds[2]…)
		  arr = @toolpath[key]

		  value = arr.is_a?(Array) ? arr[index] : arr
		  return attr ? extract_attr(value, attr) : value.to_s
	    end

		# 3 — Variable toolpath : feedrate, speed, tool, etc.
		value = @toolpath["metadata"][base]
		if value != nil
			value = value["Value"]
			if not value.is_a?(String)
			  return value.round(2).to_s
			end
			return value.to_s
		else
			return ""
		end
	  end

	  def self.process_draw_croix(args)
	    # DRAW_CROIX points mark_size
	    points_key = args[0]
	    mark_size  = args[1]&.to_f || 5.mm

	    points = self.resolve_points(points_key)
	    return if points.empty?

	    color = Sketchup::Color.new(255, 80, 80)

	    self.class.draw_croix(@view, points, mark_size, color)
	  end

	  def self.process_draw_outline(args)
	    # DRAW_OUTLINE points
	    points_key = args[0]

	    points = self.resolve_points(points_key)
	    return if points.empty?

	    @view.drawing_color = Sketchup::Color.new(200, 200, 255)
	    @view.line_width = 2
	    @view.draw(GL_LINE_LOOP, points)
	  end

	  def self.resolve_points(key)
	    case key
	    when "points"
		  self.class.build_points_from_toolpath(@toolpath)
	    else
		  puts "[Preview] points inconnus : #{key}"
		  []
	    end
	  end

	  def self.draw_toolpaths(view, toolpaths)
		return unless toolpaths
		return if toolpaths.empty?
	    # Paramètres visuels
	    default_color = Sketchup::Color.new(100, 80, 255)  # bleu clair
	    selected_color = Sketchup::Color.new(255, 160, 0)  # orange
	    point_color = Sketchup::Color.new(255, 80, 80)     # rouge pour points
	    line_width = 2
	    sel_line_width = 4
	    point_mark_size = 5.mm
	    # Si tu as un mécanisme pour connaitre la selection active côté JS/Ruby,
	    # expose la clé/keys sélectionnées dans collection.active_keys (optionnel).
	    active_keys = (toolpaths.respond_to?(:active_keys) && toolpaths.active_keys) ? toolpaths.active_keys : []
	    # Itérer les toolpaths (assume collection.toolpaths is an Array or Hash)
	    toolpaths.each_with_index do |(key, tp), idx|
		  begin
			if tp["visible"]
				tp_points = build_points_from_toolpath(tp)
				next if tp_points.nil? || tp_points.empty?
				
				# config visuelle selon sélection
				is_selected = active_keys.include?(key) || active_keys.include?(tp.object_id.to_s)
				view.line_width = is_selected ? sel_line_width : line_width
				view.drawing_color = is_selected ? selected_color : default_color

				# Choix du mode de dessin selon le type
				type = (tp.respond_to?(:type) && tp.type) || tp['type'] || tp[:type] || "Unknown"
				case type.to_s
				when /ClosedShape|Pocket|Closed/i
				  # boucle fermée
				  view.draw(GL_LINE_LOOP, tp_points)
				when /OpenShape|Line|Arc|Engrave|Profile|Route/i
				  # trait ouvert (ordonné)
				  view.draw(GL_LINE_STRIP, tp_points)
				when /DrillPattern|Hole/i
				  # pour les holes, dessiner une petite croix par point
				  draw_croix(view, tp_points, point_mark_size, point_color)
				else
				  # fallback : polyligne
				  view.draw(GL_LINE_STRIP, tp_points)
				end

				# dessiner les points en petite croix et numéroter
				draw_points_with_labels(view, tp_points, point_mark_size, point_color)
		    end
		  rescue => e
		    puts "[ToolPathDialog#draw] erreur en dessinant #{key}: #{e.message}"
		  end
	    end	  
	  end

	  def self.draw_material_outline(view, material_hash)
	    return unless material_hash

	    edges = material_hash["edges"] || []
	    view.drawing_color = Sketchup::Color.new(200,200,255)
	    edges.each do |edge|
		  pts = edge.values.map { |p| Geom::Point3d.new(*p) }
		  view.draw(GL_LINE_STRIP, pts)
	    end
	  end

	  def self.draw_original_geometry(view, original_data)
	    return unless original_data
	    # on peut réutiliser build_points_from_toolpath pour arcs/curves/faces simplifiées
	    if original_data["edges"]
		  view.drawing_color = Sketchup::Color.new(180,180,180)
		  pts = []
		  original_data["edges"].each do |edge|
			pts << Geom::Point3d.new(*edge['start'])
			pts << Geom::Point3d.new(*edge['finish'])
		  end
		  view.drawing_color = 'red'
		  view.line_width = 2
		  if not pts.empty?
		    view.draw(GL_LINES, pts)
		  end
	    end
	  end

	  # --- helpers privés ---

	  # Convertit la structure points (attendue: tp.points => array de { pos: [x,y,z] } ou simples arrays)
	  def self.build_points_from_toolpath(tp)
	    pts = []
	    # Plusieurs formats possibles supportés :
	    # - tp.points => [{ "pos": [x,y,z], "attrs": {...} }, ...]
	    # - tp['points'] => arrays
	    # - tp.point_data => [[x,y,z], ...]
		
	    if tp["points"]
	 	  tp["points"].each do |p|
		    if p.is_a?(Hash) || p.respond_to?(:[] )
			  pos = p["pos"]
			  pts << Geom::Point3d.new(*pos) if pos
		    elsif p.is_a?(Array)
			  pts << Geom::Point3d.new(*p)
			else
			  puts "un point inconnu"
		    end
		  end
	    elsif tp.respond_to?(:point_data) && tp.point_data
		  tp.point_data.each do |p|
		    pts << Geom::Point3d.new(*p)
		  end
	    elsif tp.is_a?(Hash) && tp['points']
		  tp['points'].each do |p|
		    if p.is_a?(Hash) && (p['pos'] || p[:pos])
			  pos = p['pos'] || p[:pos]
			  pts << Geom::Point3d.new(*pos)
		    elsif p.is_a?(Array)
			  pts << Geom::Point3d.new(*p)
		    end
		  end
	    else
		  # essayer de trouver d'autres champs communs
		  if tp.respond_to?(:to_a)
		    begin
			  tp.to_a.each { |p| pts << Geom::Point3d.new(*p) rescue nil }
		    rescue
		    end
		  end
	    end

	    pts
	  end

	  def self.draw_croix(view, points, mark_size, color)
	    view.drawing_color = color
	    points.each do |pt|
		  # dessiner une petite croix centrée sur pt
		  a = Geom::Point3d.new(pt.x - mark_size, pt.y, pt.z)
		  b = Geom::Point3d.new(pt.x + mark_size, pt.y, pt.z)
		  c = Geom::Point3d.new(pt.x, pt.y - mark_size, pt.z)
		  d = Geom::Point3d.new(pt.x, pt.y + mark_size, pt.z)
		  view.draw(GL_LINES, [a, b, c, d])
	    end
	  end

	  def self.draw_points_with_labels(view, points, mark_size, color)
	    view.drawing_color = color
	    points.each_with_index do |pt, i|
		  # petite croix
		  a = Geom::Point3d.new(pt.x - mark_size/2, pt.y, pt.z)
		  b = Geom::Point3d.new(pt.x + mark_size/2, pt.y, pt.z)
		  c = Geom::Point3d.new(pt.x, pt.y - mark_size/2, pt.z)
		  d = Geom::Point3d.new(pt.x, pt.y + mark_size/2, pt.z)
		  view.draw(GL_LINES, [a, b, c, d])

		  # conversion 3D → 2D
		  screen_pt = view.screen_coords(pt)

		  # label index (texte 2D ancré au point3d)
		  view.draw_text(screen_pt, i.to_s, size: 12, color: "white")
	    end
	  end
    end
  end
end
