module GNTools
  module NewPaths

    ##
    # visualisation des Toolpath (SketchUp).
    #
    class ToolpathPreview
	  # Dessiner une collection (un json)
	  
	  def self.render(view, collection, type = "material")
		case type
	    when "Toolpaths"
		  self.draw_toolpaths(view, collection["Toolpaths"])
	    when "Material"
		  self.draw_toolpaths(view, collection["Toolpaths"])
		  self.draw_material_outline(view, collection["Material"])
	    when "OriginalData"
		  self.draw_original_geometry(view, collection["OriginalData"])
	    end
	  end
	  
	  def self.draw_toolpaths(view, toolpaths)
		return unless toolpaths
		return if toolpaths.empty?
	    # Paramètres visuels
	    default_color = Sketchup::Color.new(100, 80, 255) # bleu clair
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
				  draw_holes(view, tp_points, point_mark_size, point_color)
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
		  original_data["edges"].each do |edge|
		    pts = edge.values.map { |p| Geom::Point3d.new(*p) }
		    view.draw(GL_LINE_STRIP, pts)
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

	  def self.draw_holes(view, points, mark_size, color)
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
