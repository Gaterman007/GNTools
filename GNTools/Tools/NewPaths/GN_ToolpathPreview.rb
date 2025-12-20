module GNTools
  module NewPaths

    ##
    # visualisation des Toolpath (SketchUp).
    #
    class ToolpathPreview
	  # Dessiner une collection (un json)
	  def self.render(view, collection)
	    # Paramètres visuels
	    default_color = Sketchup::Color.new(100, 80, 255) # bleu clair
	    selected_color = Sketchup::Color.new(255, 160, 0)  # orange
	    point_color = Sketchup::Color.new(255, 80, 80)     # rouge pour points
	    line_width = 2
	    sel_line_width = 4
	    point_mark_size = 5.mm
	    # Si tu as un mécanisme pour connaitre la selection active côté JS/Ruby,
	    # expose la clé/keys sélectionnées dans collection.active_keys (optionnel).
	    active_keys = (collection.respond_to?(:active_keys) && collection.active_keys) ? collection.active_keys : []
	    # Itérer les toolpaths (assume collection.toolpaths is an Array or Hash)
	    collection.each_with_index do |(key, tp), idx|
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
  end
end

#$toolpath_preview ||= GNTools::NewPaths::ToolpathObserver.new
#Sketchup.active_model.active_view.add_observer($toolpath_preview)