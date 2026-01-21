module GNTools
  EPSILON = 1e-6

  # =========================================================
  # Géométrie 2D bas niveau
  # =========================================================
  module Geom2D
    EPS = GNTools::EPSILON

    def self.area2(a,b,c)
	  (b[0]-a[0])*(c[1]-a[1]) - (b[1]-a[1])*(c[0]-a[0])
    end

    def self.ccw?(a,b,c)
	  area2(a,b,c) > EPS
    end

    def self.cw?(a,b,c)
	  area2(a,b,c) < -EPS
    end

    def self.collinear?(a,b,c)
	  area2(a,b,c).abs < EPS
    end

    def self.share_endpoint?(a,b,c,d)
	  a==c || a==d || b==c || b==d
    end

    def self.segments_intersect_strict?(a,b,c,d)
      return false if share_endpoint?(a,b,c,d)

      o1 = area2(a,b,c)
      o2 = area2(a,b,d)
      o3 = area2(c,d,a)
      o4 = area2(c,d,b)

      o1 * o2 < -EPS && o3 * o4 < -EPS
    end

    # Distance au carré entre deux points [x,y]
    def self.distance2(a,b)
	  dx = a[0] - b[0]
	  dy = a[1] - b[1]
  	  dx*dx + dy*dy
    end

    # Distance euclidienne classique
    def self.distance(a,b)
	  Math.sqrt(distance2(a,b))
    end
    
    def self.point_in_polygon?(pt, poly)
      x, y = pt
      inside = false

      n = poly.length
      return false if n < 3

      j = n - 1
      (0...n).each do |i|
        xi, yi = poly[i]
        xj, yj = poly[j]

        intersect = ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi + 0.0) + xi)

        inside = !inside if intersect
        j = i
      end

      inside
    end  
  end

  # =========================================================
  # Triangle utilitaire
  # =========================================================
  class Triangle2D
    def self.edges(tri)
	  [[tri[0],tri[1]],[tri[1],tri[2]],[tri[2],tri[0]]]
    end

    def self.contains_point?(tri, p, strict: false)
      a,b,c = tri

      w1 = Geom2D.area2(a,b,p)
      w2 = Geom2D.area2(b,c,p)
      w3 = Geom2D.area2(c,a,p)

      if strict
        w1 > Geom2D::EPS && w2 > Geom2D::EPS && w3 > Geom2D::EPS
      else
        (w1 >= -Geom2D::EPS &&
         w2 >= -Geom2D::EPS &&
         w3 >= -Geom2D::EPS) ||
        (w1 <= Geom2D::EPS &&
         w2 <= Geom2D::EPS &&
         w3 <= Geom2D::EPS)
      end
    end

    def self.intersects_segment?(tri, p, q)
	  return true if contains_point?(tri, p, strict: true)
	  return true if contains_point?(tri, q, strict: true)

	  edges(tri).any? do |a,b|
	    Geom2D.segments_intersect_strict?(p,q,a,b)
	  end
    end
		
  end

  module Polygon2D
    extend self

    # -----------------------------
    # Structure
    # -----------------------------

    def edges(loop)
	  loop.each_cons(2).map { |a,b| [a,b] } +
	    [[loop.last, loop.first]]
    end

    def area(loop)
	  loop.each_with_index.sum do |p,i|
	    q = loop[(i+1) % loop.size]
	    (p[0]*q[1] - q[0]*p[1])
	  end * 0.5
    end

    def ensure_ccw(loop)
	  area(loop) < 0 ? loop.reverse : loop
    end

    # -----------------------------
    # Nettoyage
    # -----------------------------

    def cleanup_degenerate_vertices!(loop)
	  i = 0
	  while i < loop.size && loop.size > 3
	    a = loop[(i-1) % loop.size]
	    b = loop[i]
	    c = loop[(i+1) % loop.size]

	    if a == b || b == c || Geom2D.collinear?(a,b,c)
		  loop.delete_at(i)
	    else
		  i += 1
	    end
	  end
    end

    # -----------------------------
    # Tests topologiques
    # -----------------------------

    def diagonal_intersects_loop?(p0, p1, loop)
	  edges(loop).any? do |a,b|
	    next false if [a,b].include?(p0) || [a,b].include?(p1)
	    Geom2D.segments_intersect_strict?(p0,p1,a,b)
	  end
    end
  end


  module Tessellator


    # =========================================================
    # Test intersection triangle / triangle
    # =========================================================   
    def self.triangle_intrudes?(ear, hole_tri)
      # sommet de l'ear strictement dans le trou
      return true if ear.any? { |p|
        Triangle2D.contains_point?(hole_tri, p, strict: true)
      }

      # intersection stricte arête/arête
      Triangle2D.edges(ear).any? { |e|
        Triangle2D.edges(hole_tri).any? { |f|
          Geom2D.segments_intersect_strict?(e[0], e[1], f[0], f[1])
        }
      }
    end

    def self.debug_draw_loop(group, loop, step)

      g = group.entities.add_group
      g.name = "earcut_step_#{step}"

      z = step * 0.05
      pts = loop.map { |p| Geom::Point3d.new(p[0], p[1], z) }

      pts.each_cons(2) { |a,b| g.entities.add_line(a,b) }
      g.entities.add_line(pts.last, pts.first)
    end

    # =========================================================
    # Ear clipping générique (avec trous)
    # =========================================================
    def self.ear_cut(verts, ccw: true)
      verts = verts.dup
      triangles = []
#      earcut_group = Sketchup.active_model.active_entities.add_group 
      step = 0
#      debug_draw_loop(earcut_group,verts, step)

      while verts.size >= 3
        ear_found = false

        verts.each_with_index do |p1,i|
          p0 = verts[i-1]
          p2 = verts[(i+1)%verts.size]

          # convexité locale
          ok_orient = ccw ?
            Geom2D.ccw?(p0,p1,p2) :
            Geom2D.cw?(p0,p1,p2)
          next unless ok_orient

          tri = [p0,p1,p2]
          
          # aucun autre sommet strictement à l'intérieur
          next if verts.any? { |pt|
            !tri.include?(pt) &&
            Triangle2D.contains_point?(tri, pt)
          }
          
          # la diagonale ne coupe aucune arête existante
          next if Polygon2D.diagonal_intersects_loop?(p0, p2, verts)

          triangles << tri
          verts.delete_at(i)
          Polygon2D.cleanup_degenerate_vertices!(verts)
#          step += 1
#          debug_draw_loop(earcut_group,verts, step)

          ear_found = true
          break
        end

        if !ear_found
          earcut_group = Sketchup.active_model.active_entities.add_group 
          step = 0
          debug_draw_loop(earcut_group,verts, step)
          
          verts.each_with_index do |p1,i|
            p0 = verts[i-1]
            p2 = verts[(i+1)%verts.size]

            puts "---- Ear test #{i}"
            puts " point p0 #{p0}"
            puts " point p1 #{p1}"
            puts " point p2 #{p2}"
            
            pt0 = Geom::Point3d.new(p0[0], p0[1], 0.0)
            pt1 = Geom::Point3d.new(p1[0], p1[1], 0.0)
            pt2 = Geom::Point3d.new(p2[0], p2[1], 0.0)
            g = earcut_group.entities.add_group
            g.name = "earcut_triangle_test_#{step}"
            g.entities.add_line(pt0,pt1)
            g.entities.add_line(pt1,pt2)
            g.entities.add_line(pt2,pt0)
            
          end
          
          verts.each_with_index do |p1,i|
            p0 = verts[i-1]
            p2 = verts[(i+1)%verts.size]

            puts "---- Ear test #{i}"
            puts "convex: #{Geom2D.ccw?(p0,p1,p2)}"
            puts "inside: #{verts.any? { |pt| ![p0,p1,p2].include?(pt) &&
              Triangle2D.contains_point?( [p0,p1,p2], pt, strict: true) }}"
            puts "diag intersect: #{Polygon2D.diagonal_intersects_loop?(p0,p2,verts)}"
          end

          
        end

        break unless ear_found
      end

      triangles << verts if verts.size == 3
      triangles
    end

    # =========================================================
    # API principale
    # =========================================================
    def self.tessellate(outer, holes=[])
	
      outer = Polygon2D.ensure_ccw(outer)

	  result_loops = split_polygon_with_holes_multi(outer, holes)
	  
	  triangles = []
	  result_loops.each do |loop|
		loop = Polygon2D.ensure_ccw(loop)
		triangles.concat(ear_cut(loop, ccw: true))
	  end
	  
	  triangles
    end
 
	def self.valid_bridge?(hp, lp, loop, other_loops)
	  # Contour courant
	  Polygon2D.edges(loop).each do |a,b|
		next if a == hp || a == lp || b == hp || b == lp
		return false if Geom2D.segments_intersect_strict?(hp, lp, a, b)
	  end

	  # Autres loops (trous / loops restantes)
	  other_loops.each do |ol|
		Polygon2D.edges(ol).each do |a,b|
		  next if a == hp || a == lp || b == hp || b == lp
		  return false if Geom2D.segments_intersect_strict?(hp, lp, a, b)
		end
	  end

	  true
	end

	def self.find_two_bridges(loop, hole, other_loops)
	  candidates = []

	  # 1️ Tous les bridges valides
	  hole.each do |hp|
		loop.each do |lp|
		  if valid_bridge?(hp, lp, loop, other_loops)
			candidates << [hp, lp]
		  end
		end
	  end

	  return nil if candidates.size < 2

	  best_pair = nil
	  best_score = -Float::INFINITY

	  # 2️ Sélection de la meilleure paire
	  candidates.each_with_index do |b1, i|
		hp1, lp1 = b1

		candidates[(i+1)..-1].each do |b2|
		  hp2, lp2 = b2

		  # ❌ mêmes sommets
		  next if hp1 == hp2
		  next if lp1 == lp2

		  # ❌ bridges qui se croisent
		  next if Geom2D.segments_intersect_strict?(hp1, lp1, hp2, lp2)

		  # 3️ Critère : distance maximale sur le trou
		  score = GNTools::Geom2D.distance2(hp1, hp2)

		  if score > best_score
			best_score = score
            best_pair = [
              { hole: hp1, loop: lp1 },
              { hole: hp2, loop: lp2 }
            ]
#			best_pair = [b1, b2]
		  end
		end
	  end

	  best_pair
	end

	def self.slice_cycle(arr, i0, i1)
	  if i0 <= i1
		arr[i0..i1]
	  else
		arr[i0..-1] + arr[0..i1]
	  end
	end

    def self.hole_inside_loop?(hole, loop)
      hole.all? { |pt| GNTools::Geom2D.point_in_polygon?(pt, loop) }
    end

    def self.split_polygon_with_holes_multi(outer, holes)
      loops = [outer.dup]

      holes.each do |hole|
        split_done = false

        loops.each_with_index do |loop, idx|
          next unless hole_inside_loop?(hole, loop)

          bridges = find_two_bridges(loop, hole, holes)
          raise "Impossible de trouver 2 bridges" unless bridges && bridges.size == 2

          b1, b2 = bridges
          h1, l1 = b1[:hole], b1[:loop]
          h2, l2 = b2[:hole], b2[:loop]

          li1 = loop.index(l1)
          li2 = loop.index(l2)
          hi1 = hole.index(h1)
          hi2 = hole.index(h2)

          raise "Index nil" if [li1,li2,hi1,hi2].any?(&:nil?)

          hole_path_1  = slice_cycle(hole, hi2, hi1)
          hole_path_2  = slice_cycle(hole, hi1, hi2)
          outer_path_1 = slice_cycle(loop, li1, li2)
          outer_path_2 = slice_cycle(loop, li2, li1)

          loop_a = outer_path_1 + hole_path_1
          loop_b = outer_path_2 + hole_path_2

          loops.delete_at(idx)
          loops << loop_a
          loops << loop_b

          split_done = true
          break
        end

        raise "Trou non contenu dans aucune loop" unless split_done
      end

      loops
    end

  end
  
  module Geometry
  
  
	class Face
	  attr_reader :normal
	  attr_reader :outer_loop
	  attr_reader :inner_loops # Array<Loop>

	  # loops = [outer_loop, hole1, hole2, ...]
	  # chaque loop expose : vertices -> [Geom::Point3d]
	  def initialize(outer_loop:, inner_loops: [], normal: nil)
		@outer_loop  = outer_loop
		@inner_loops = inner_loops.dup

		@normal = normal ?
		  Vector.new(normal).normalize :
		  outer_loop.normal.normalize

		enforce_loop_orientation!
		validate!
	  end

	  def signed_area_2d(loop2d)
	    area = 0.0
	    loop2d.each_with_index do |p, i|
		  q = loop2d[(i+1) % loop2d.size]
		  area += p[0] * q[1] - q[0] * p[1]
	    end
	    area * 0.5
	  end

	  def enforce_loop_orientation!
	    if outer_loop.signed_area(normal) < 0
		  outer_loop.reverse!
	    end

	    inner_loops.each do |loop|
		  if loop.signed_area(normal) > 0
		    loop.reverse!
		  end
	    end
	  end

	  def validate!
	    raise "Outer loop required" unless outer_loop
	    raise "Face must be planar" unless planar?
	  end

	  def planar?(eps = GNTools::EPSILON)
	    pt = outer_loop.vertices.first
	    all_vertices.all? do |v|
		  ((v - pt).dot(normal)).abs < eps
	    end
	  end

	  # -----------------------------
	  # Accesseurs
	  # -----------------------------

	  def loops
	    [outer_loop, *inner_loops]
	  end

	  def vertices
	    outer_loop.vertices
	  end

	  def all_vertices
	    loops.flat_map(&:vertices)
	  end

	  def edges
	    outer_loop.edges
	  end

	  def all_edges
	    loops.flat_map(&:edges)
	  end

	  # -----------------------------
	  # Repère local (plan de la face)
	  # -----------------------------

	  def local_frame
		n = @normal

		ref =
		  if n.z.abs < 0.9
			Geom::Vector3d.new(0, 0, 1)
		  else
			Geom::Vector3d.new(0, 1, 0)
		  end

		u = n.cross(ref).normalize
		v = n.cross(u).normalize

		[u, v, n]
	  end

	  # -----------------------------
	  # Mapping 3D -> 2D
	  # -----------------------------

	  def map3d2d(pt, origin, u, v)
		vec = pt - origin
		[vec.dot(u), vec.dot(v)]
	  end

	  def project_loops_to_2d
		origin = outer_loop.centroid
		u, v, = local_frame

		outer_2d = outer_loop.vertices.map do |pt|
		  map3d2d(pt, origin, u, v)
		end

		holes_2d = inner_loops.map do |loop|
		  loop.vertices.map do |pt|
			map3d2d(pt, origin, u, v)
		  end
		end

		outer_2d.reverse! if signed_area_2d(outer_2d) < 0
		holes_2d.each { |h| h.reverse! if signed_area_2d(h) > 0 }

		{
		  origin: origin,
		  u: u,
		  v: v,
		  outer: outer_2d,
		  holes: holes_2d
		}
	  end

	  # -----------------------------
	  # Mapping 2D -> 3D
	  # -----------------------------

	  def map2d3d(pt2d, origin, u, v)
		origin + u * pt2d[0] + v * pt2d[1]
	  end

	  # -----------------------------
	  # Triangles finaux (3D)
	  # -----------------------------

	  def triangles
	    @triangles ||= compute_triangles
	  end

	  def compute_triangles
	  
	    data = project_loops_to_2d

	    data[:outer].reverse! if signed_area_2d(data[:outer]) < 0

	    data[:holes].each do |h|
		  h.reverse! if signed_area_2d(h) > 0
	    end

		
#		data[:holes].each_with_index do |h,i|
#		  puts "hole #{i} area 2d = #{signed_area_2d(h)}"
#		end

	  if false
	  if data[:holes].size > 0
        puts "outer_loop = ["
        data[:outer].each { |p| puts "  #{p}," }
        puts "]"
        puts "holes = ["
        data[:holes].each do |hole|
          puts "  ["
          hole.each { |p| puts "    #{p}," }
          puts "  ],"
        end
        puts "]"
	  end
      end
	    tris_2d = Tessellator.tessellate(data[:outer], data[:holes])

	    tris_2d.map do |tri|
		  tri.map { |pt2d| map2d3d(pt2d, data[:origin], data[:u], data[:v]) }
	    end
	  end

	  # -----------------------------
	  # Debug / Export
	  # -----------------------------

	  def to_hash
		{
		  "normal"      => normal.to_a,
		  "outer_loop"  => outer_loop.vertices.map(&:to_a),
		  "inner_loops" => inner_loops.map { |l| l.vertices.map(&:to_a) }
		}
	  end

	  def to_s
		"Face(loops=#{loops.size}, normal=#{normal})"
	  end
	end
  end
end
