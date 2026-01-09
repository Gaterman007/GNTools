require_relative 'GN_ScriptEngine.rb'

module GNTools
  module NewPaths

    ##
    # visualisation des Toolpath (SketchUp).
    #
    class ToolpathPreview < BaseScriptEngine
	  # Dessiner une collection (un json)
      COMMANDS = {
        "MOVE" => :MOVE,
        "LINE" => :LINE,
        "LINES" => :LINES,
		"DRAW_CIRCLE"=> :DRAW_CIRCLE,
        "DRAW_CROIX" => :DRAW_CROIX,
        "DRAW_POINTS_WITH_LABEL" => :DRAW_POINTS_WITH_LABEL,
		"DRAW_MATERIAL" => :DRAW_MATERIAL,
		"DRAW_MATERIAL_WITH_TOOLPATH" => :DRAW_MATERIAL_WITH_TOOLPATH
      }


	  DEFAULT = {
	    "Line" => {
		  "Original"   => <<~PREV,
			DRAW_CROIX({CurrentTp.points[0].pos[0]} {CurrentTp.points[0].pos[1]} {CurrentTp.points[0].pos[2]})
			DRAW_CROIX({CurrentTp.points[1].pos[0]} {CurrentTp.points[1].pos[1]} {CurrentTp.points[1].pos[2]})
			MOVE ({CurrentTp.points[0].pos[0]} {CurrentTp.points[0].pos[1]} {CurrentTp.points[0].pos[2]})
			LINE ({CurrentTp.points[1].pos[0]} {CurrentTp.points[1].pos[1]} {CurrentTp.points[1].pos[2]})
			DRAW_POINTS_WITH_LABEL({CurrentTp.points})
		  PREV
		  "Actuel"    => <<~PREV,
			DRAW_CROIX({CurrentTp.points[0].pos[0]} {CurrentTp.points[0].pos[1]} {CurrentTp.points[0].pos[2]})
		  PREV
		  "Chemin"    => <<~PREV,
			MOVE ({CurrentTp.points[0].pos[0]} {CurrentTp.points[0].pos[1]} {Material.safeHeight})
			LINE ({CurrentTp.points[0].pos[0]} {CurrentTp.points[0].pos[1]} {CurrentTp.points[0].pos[2]})
			CYLINDER ({CurrentTp.points[0].pos[0]} {CurrentTp.points[0].pos[1]} {CurrentTp.metadata.holesize.Value} {CurrentTp.metadata.depth.Value})
		    {foreach p in CurrentTp.points}
			  LINE ({p.pos[0]} {p.pos[1]} {CurrentTp.metadata.depth.Value})
		    {end}
		    MOVE ({points[-1].x} {points[-1].y} {Material.safeHeight})
		    DRAW_POLYLINE ({points})
		  PREV
		  "Simulation"  => <<~PREV,
		    DRAW_MATERIAL ({OriginalData})
		    DRAW_FACE ({CurrentTp.points[0]} {CurrentTp.metadata.depth.Value})
		  PREV
	    },
	    "Hole" => {
		  "Original"   => <<~PREV,
		    DRAW_CROIX ({CurrentTp.points[0].pos[0]} {CurrentTp.points[0].pos[1]} {CurrentTp.points[0].pos[2]})
		    DRAW_CIRCLE ({CurrentTp.points[0]} {CurrentTp.metadata.holesize.Value})
		  PREV
		  "Actuel"    => <<~PREV,
		    DRAW_CIRCLE ({CurrentTp.points[0]} {CurrentTp.metadata.holesize.Value})
		  PREV
		  "Chemin"    => <<~PREV,
			DRAW_POINTS_WITH_LABEL({CurrentTp.points})
		    DRAW_CYLINDER ({CurrentTp.points[0]} {CurrentTp.metadata.holesize.Value} {CurrentTp.metadata.depth.Value})
		    DRAW_MATERIAL ({OriginalData})
		  PREV
		  "Simulation"  => <<~PREV,
			DRAW_MATERIAL_WITH_TOOLPATH ({OriginalData} {CurrentTp})
		  PREV
	    }
	  }
	  	  
	  attr_accessor:previews
	  attr_accessor :global_vars

      def self.instance
        @instance ||= new
      end
	  
      def initialize()
		super()
		@previews = load_all_previews
      end

      def parse_command_line(line)
        return nil unless line =~ /\A(\w+)\s*\((.*)\)\z/

        cmd_name = Regexp.last_match(1)
        raw_args = Regexp.last_match(2)

        cmd = COMMANDS[cmd_name]
        return nil unless cmd

        args = parse_arguments(raw_args)

        [cmd, args]
      end

      def parse_arguments(arg_string)
        return [] if arg_string.strip.empty?

        arg_string.scan(/\{([^\}]+)\}/).map do |(expr)|
          eval_in_schema(expr)
        end
      end

 	  # -------------------------------------------------
	  # Évaluation des expressions {…} dans le script
	  # -------------------------------------------------
	  def eval_in_schema(expr)
	    expr = expr.strip
	    return nil if expr.empty?

	    # 1 — Literal numérique
	    return expr.to_f if expr.match?(/\A-?\d+(\.\d+)?\z/)

	    # 2 — Vérifier les variables locales / globales
	    if @vars.key?(expr)
		  val = @vars[expr]
		  return val
	    end

	    # 3 — Accès aux objets imbriqués via . et tableaux []
	    if expr.include?(".") || expr.include?("[")
          val = resolve_path(expr)
		  return val
	    end

	    # 4 — Si rien trouvé, retourner vide
	    ""
	  end

	  # -------------------------------------------------
	  # Résolution des chemins imbriqués
	  # Exemple :
	  # CurrentTp.points[0].x
	  # Material.metadata.depth.Value
	  # -------------------------------------------------
	  def resolve_path(path)
	    parts = path.split(".")
	    first = parts.shift

 	    # Chercher dans les vars
		# Si c'est CurrentTp, on a dans vars deja CurrentTp
	    obj = @vars[first]
	    return "" unless obj
	    parts.each do |part|
		  # Accès tableau : points[0]
		  if part =~ /(\w+)\[(\d+)\]/
		    key = $1
		    idx = $2.to_i
		    if obj.is_a?(Hash)
			  obj = obj[key]
		    end
		    if obj.is_a?(Array)
			  obj = obj[idx]
		    else
			  return ""
		    end
		  else
		    # Accès Hash ou objet
		    if obj.is_a?(Hash)
			  obj = obj[part]
		    elsif obj.respond_to?(part)
			  obj = obj.send(part)
		    else
			  return ""
		    end
		  end
		  return "" if obj.nil?
	    end

	    obj
	  end


      def handle_instruction(inst)
        parsed = parse_command_line(inst)
	    return unless parsed

		command, args = parsed
	  
        case command
        when :MOVE      then cmd_move(args)
        when :LINE      then cmd_line(args)
        when :DRAW_CROIX then cmd_draw_croix(args)
		when :DRAW_CIRCLE then cmd_draw_circle(args)
        when :DRAW_POINTS_WITH_LABEL then cmd_draw_points_with_label(args)
		when :DRAW_MATERIAL then cmd_draw_material(args)
		when :DRAW_MATERIAL_WITH_TOOLPATH then cmd_draw_material_with_toolpath(args)
		
        end
      end


	  def flatten_args(obj, out = [])
	   case obj
	    when Array
		  obj.each { |e| flatten_args(e, out) }
	    else
		  out << obj
	    end
	    out
	  end

	  def resolve_point(args)
	    flat = flatten_args(args)

	    # 1 — Geom::Point3d direct
	    return flat.first if flat.first.is_a?(Geom::Point3d)

	    # 2 — Trois nombres consécutifs
	    if flat.size >= 3 && flat[0,3].all? { |v| v.is_a?(Numeric) }
		  return Geom::Point3d.new(*flat[0,3])
	    end

	    # 3 — Tableau [x,y,z]
	    v = flat.first
	    if v.is_a?(Array) && v.size >= 3 && v[0,3].all? { |n| n.is_a?(Numeric) }
		  return Geom::Point3d.new(*v[0,3])
	    end

		# 4 — Hash avec pos (string ou symbol)
		if v.is_a?(Hash)
		  pos = v[:pos] || v["pos"]
		  if pos.is_a?(Array) && pos.size >= 3
			return Geom::Point3d.new(*pos[0,3])
		  end
		end

	    # 5 — Objet avec pos
	    if v.respond_to?(:pos)
		  return resolve_point([v.pos])
	    end

	    # 6 — Objet avec x,y,z
	    if v.respond_to?(:x) && v.respond_to?(:y) && v.respond_to?(:z)
		  return Geom::Point3d.new(v.x, v.y, v.z)
	    end

	    nil
	  end

	  def resolve_points(args)
	    pts = []

	    flatten_args(args).each do |v|
		  pt = resolve_point([v])
		  pts << pt if pt
	    end

	    pts
	  end
	  
	  def resolve_numbers(args)
	    flatten_args(args)
		  .select { |v| v.is_a?(Numeric) }
	  end

	  def resolve_number(args)
	    resolve_numbers(args).first
	  end

      # -----------------------------------
      # Commandes
      # -----------------------------------
      def cmd_move(args)
	    pt = resolve_point(args)
		return unless pt
        @last_pos = pt
      end

      def cmd_line(args)
        p1 = @last_pos
		pt = resolve_point(args)
        p2 = pt
        return unless p1 && p2
        @view.draw(GL_LINES, [p1, p2]) if @view 
        @last_pos = p2
      end

      def cmd_draw_croix(args)
		pt = resolve_point(args)
		return unless pt
        size = 5.mm

        a = Geom::Point3d.new(pt.x - size, pt.y, pt.z)
        b = Geom::Point3d.new(pt.x + size, pt.y, pt.z)
        c = Geom::Point3d.new(pt.x, pt.y - size, pt.z)
        d = Geom::Point3d.new(pt.x, pt.y + size, pt.z)
        @view.draw(GL_LINES, [a, b, c, d]) if @view
      end

	  def cmd_draw_circle(args)
		# ici on a point3d et radius
	    pt = resolve_point(args)
	    radius = resolve_number(args)

	    return unless pt && radius

	    segments = 32
	    pts = (0..segments).map do |i|
		  angle = 2.0 * Math::PI * i / segments
		  Geom::Point3d.new(
		    pt.x + Math.cos(angle) * radius.mm,
		    pt.y + Math.sin(angle) * radius.mm,
		    pt.z
		  )
	    end

	    @view.draw(GL_LINE_STRIP, pts) if @view  
	  end

      def cmd_draw_points_with_label(args)
		pts = resolve_points(args)
		return if pts.empty?

        pts.each_with_index do |p, i|
		  # conversion 3D → 2D
		  screen_pt = @view.screen_coords(p)
		  # label index (texte 2D ancré au point3d)
		  @view.draw_text(screen_pt, i.to_s, size: 12, color: "white")
        end
      end

	  def compute_normal(pts)
	    normal = Geom::Vector3d.new(0, 0, 0)

	    pts.each_with_index do |p0, i|
		  p1 = pts[(i + 1) % pts.length]
		  normal.x += (p0.y - p1.y) * (p0.z + p1.z)
		  normal.y += (p0.z - p1.z) * (p0.x + p1.x)
		  normal.z += (p0.x - p1.x) * (p0.y + p1.y)
	    end

	    normal.normalize!
	    normal
	  end

	  def ensure_orientation(pts, expected_normal)
		poly_normal = compute_normal(pts)
		if poly_normal.dot(expected_normal) < 0
		  pts.reverse
		end
		pts
	  end

	  def triangulate(pts)
	    tris = []
	    base = pts[0]

	    (1..pts.length - 2).each do |i|
		  tris << [base, pts[i], pts[i + 1]]
	    end

	    tris
	  end

	  def cmd_draw_material_with_toolpath(args)
	    puts "draw_material_with_toolpath args"
		puts "------ OriginalData --------"
		puts JSON.pretty_generate(args[0])
		puts "-------- Toolpath ----------"
		puts JSON.pretty_generate(args[1])
		puts "----------------------------"
		# orignial data
		oridata = args[0]
		if oridata.is_a?(Array)
			oridata = oridata[0]
		end
		current_toolpath = args[1]
		cmd_draw_material(oridata)
	  end

	  def triangulate_with_holes(loops_pts)
		outer = loops_pts
		return [] unless outer && outer.size >= 3
		tris = []
		p0 = outer[0]
		(1...(outer.size - 1)).each do |i|
		  tris << [p0, outer[i], outer[i + 1]]
		end
		tris
	  end

	  def edges_to_points(edges)
	    pts = []
	    edges.each do |e|
		  pts << Geom::Point3d.new(e["start"])
	    end
	    pts
	  end

	  def update_preview_bbox(points)
	    bb = Geom::BoundingBox.new
	    points.each { |pt| bb.add(pt) }
	    @preview_bbox = bb
	  end

	  def cmd_draw_material(args)
#		puts "------ Original data ---------"
#		puts args
#		puts "------------------------------"

	    oridata = args.is_a?(Array) ? args[0] : args

	    edge_pts = []
	    if oridata["edges"]
		  oridata["edges"].each do |e|
		    p0 = Geom::Point3d.new(e["start"])
		    p1 = Geom::Point3d.new(e["finish"])
		    edge_pts << p0 << p1
		  end
	    end
	    draw_pts = []
	    draw_normals = []
	    oridata["faces"].each do |face_data|
		  normal = Geom::Vector3d.new(face_data["normal"])
		  normal.normalize!

		  # Triangulation avec holes
		  # triangulate_with_holes doit retourner un array de triangles [[pt1,pt2,pt3], ...]
		  # face_data["inner_loops"]
		  # face_data["outer_loop"]
		  triangles = triangulate_with_holes(face_data["outer_loop"])

		  triangles.each do |tri|
		    tri.each do |pt|
			  draw_pts << pt
			  draw_normals << normal
		    end
		  end
	    end
	    # Dessin OpenGL
	    @view.drawing_color = "lightgrey" if @view
	    @view.draw(GL_TRIANGLES, draw_pts, normals: draw_normals, depth: 2) if @view

	    @view.drawing_color = Sketchup::Color.new(0, 0, 0) if @view
	    @view.draw(GL_LINES, edge_pts, line_width: 1, depth: 2) if @view

		update_preview_bbox(draw_pts + edge_pts)
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
	  
	  def self.render(view, collection, type = "Original",vars = {})
		return unless collection["Toolpaths"]
		engine = self.instance
		self.instance.global_vars = Marshal.load(Marshal.dump(collection.read()))
		self.instance.instance_variable_set(:@view, view)
		self.instance.instance_variable_set(:@vars, self.instance.global_vars.merge(vars))
		
#		puts "Global Variables"
#		puts "---------------------"
#		puts JSON.pretty_generate(self.instance.global_vars)
#		puts "---------------------"
		collection["Toolpaths"].each do |key, toolpath|
		  script_text = get_script(toolpath['type'],type)
		  self.instance.compile(script_text, self.instance.global_vars["Toolpaths"][key])
		end
	  end

	  def draw_material_outline(view, material_hash)
	    return unless material_hash

	    edges = material_hash["edges"] || []
	    view.drawing_color = Sketchup::Color.new(200,200,255)
	    edges.each do |edge|
		  pts = edge.values.map { |p| Geom::Point3d.new(*p) }
		  view.draw(GL_LINE_STRIP, pts)
	    end
	  end

	  def draw_original_geometry(view, original_data)
	    return unless original_data
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

	  def draw_points_with_labels(view, points, mark_size, color)
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
