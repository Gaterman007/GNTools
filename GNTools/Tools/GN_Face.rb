module GNTools

  module Tessellator

    # -----------------------------
    # Fonctions utilitaires 2D
    # -----------------------------
    def self.polygon_area(loop)
      area = 0.0
      loop.each_with_index do |p,i|
        q = loop[(i+1) % loop.size]
        area += (p[0]*q[1] - q[0]*p[1])
      end
      area * 0.5
    end

    def self.ensure_ccw(loop)
      polygon_area(loop) < 0 ? loop.reverse : loop
    end    
    
    
    def self.convex?(p0, p1, p2)
      cross = (p1[0]-p0[0])*(p2[1]-p0[1]) -
              (p1[1]-p0[1])*(p2[0]-p0[0])
      cross > 0
    end

    def self.triangle_intersect?(tri_a, tri_b)
      # 1️ Vérifie si un point de tri_a est **à l'intérieur strict** de tri_b
      return true if tri_a.any? { |pt| point_in_triangle_strict?(pt, tri_b) }
      return true if tri_b.any? { |pt| point_in_triangle_strict?(pt, tri_a) }

      # 2️ Vérifie si les arêtes se croisent vraiment
      edges_a = tri_a.each_cons(2).to_a + [[tri_a.last, tri_a.first]]
      edges_b = tri_b.each_cons(2).to_a + [[tri_b.last, tri_b.first]]

      edges_a.any? do |a1, a2|
        edges_b.any? do |b1, b2|
          segments_intersect_strict?(a1, a2, b1, b2)
        end
      end
    end

    # version stricte de point_in_triangle : bord inclus = false
    def self.point_in_triangle_strict?(pt, tri)
      ax, ay = tri[0]; bx, by = tri[1]; cx, cy = tri[2]; px, py = pt
      v0x, v0y = cx - ax, cy - ay
      v1x, v1y = bx - ax, by - ay
      v2x, v2y = px - ax, py - ay
      dot00 = v0x*v0x + v0y*v0y
      dot01 = v0x*v1x + v0y*v1y
      dot02 = v0x*v2x + v0y*v2y
      dot11 = v1x*v1x + v1y*v1y
      dot12 = v1x*v2x + v1y*v2y
      denom = dot00*dot11 - dot01*dot01
      return false if denom.abs < 1e-12
      u = (dot11*dot02 - dot01*dot12) / denom
      v = (dot00*dot12 - dot01*dot02) / denom
      u > 1e-12 && v > 1e-12 && (u + v) < 1-1e-12
    end

    # version stricte de segments_intersect : ignore si ils sont colinéaires ou partagent un point
    def self.segments_intersect_strict?(p1, p2, q1, q2)
      return false if [p1,p2].any? { |pt| [q1,q2].include?(pt) } # partage de sommet = ok
      return false if collinear?(p1,p2,q1) && collinear?(p1,p2,q2) # colinéaire = ok
      ccw?(p1,q1,q2) != ccw?(p2,q1,q2) && ccw?(p1,p2,q1) != ccw?(p1,p2,q2)
    end

    def self.collinear?(p0,p1,p2)
      (p1[0]-p0[0])*(p2[1]-p0[1]) - (p1[1]-p0[1])*(p2[0]-p0[0]) == 0
    end

    def self.point_in_triangle?(pt, tri)
      ax, ay = tri[0]; bx, by = tri[1]; cx, cy = tri[2]; px, py = pt
      v0x, v0y = cx - ax, cy - ay
      v1x, v1y = bx - ax, by - ay
      v2x, v2y = px - ax, py - ay
      dot00 = v0x*v0x + v0y*v0y
      dot01 = v0x*v1x + v0y*v1y
      dot02 = v0x*v2x + v0y*v2y
      dot11 = v1x*v1x + v1y*v1y
      dot12 = v1x*v2x + v1y*v2y
      denom = dot00*dot11 - dot01*dot01
      return false if denom.abs < 1e-12
      u = (dot11*dot02 - dot01*dot12) / denom
      v = (dot00*dot12 - dot01*dot02) / denom
      u >= 0 && v >= 0 && (u + v) <= 1
    end

    def self.segments_intersect?(p1, p2, q1, q2)
      ccw?(p1,q1,q2) != ccw?(p2,q1,q2) && ccw?(p1,p2,q1) != ccw?(p1,p2,q2)
    end

    def self.ccw?(a,b,c)
      (c[1]-a[1])*(b[0]-a[0]) > (b[1]-a[1])*(c[0]-a[0])
    end

    def self.distance2(a,b)
      dx = a[0]-b[0]; dy = a[1]-b[1]; dx*dx + dy*dy
    end

    def self.polygon_edges(loop)
      loop.each_cons(2).map { |a,b| [a,b] } + [[loop.last, loop.first]]
    end

    def self.visible?(p, q, edges)
      edges.none? do |a,b|
        next false if [a,b].include?(p) || [a,b].include?(q)
        segments_intersect?(p,q,a,b)
      end
    end

    def self.rightmost_vertex(loop)
      loop.max_by { |p| [p[0], -p[1]] }
    end

    # -----------------------------
    # Créer des ponts entre outer loop et trous
    # -----------------------------
	def self.bridge_holes(outer, holes)
	  loop = outer.dup

	  holes.each do |hole|
		# 1️ trouver le point le plus à droite du hole
		hole_index = hole.each_with_index.max_by { |p, i| p[0] }[1]
		h = hole[hole_index]

		# 2️ trouver le point le plus proche à droite dans l'outer
		outer_index = loop.each_with_index.min_by do |p, i|
		  p[0] >= h[0] ? (p[0] - h[0]) : Float::INFINITY
		end[1]

		# 3️ reconstruire le hole dans le bon ordre
		hole_path = []
		hole.size.times do |i|
		  hole_path << hole[(hole_index + i) % hole.size]
		end
        hole_path << hole_path.first

		# 4️ insérer le hole dans l'outer
		new_loop = []

        # partie 1 : outer jusqu'au bridge inclus
        new_loop = loop[0..outer_index]

        # partie 2 : hole entier (dans le bon ordre)
        new_loop.concat(hole_path)

        # partie 3 : suite de l'outer après le bridge
        new_loop.concat(loop[(outer_index)..-1])

		loop = new_loop
	  end

	  loop
	end

	def self.tri_area2(p0, p1, p2)
	  (p1[0]-p0[0])*(p2[1]-p0[1]) -
	  (p1[1]-p0[1])*(p2[0]-p0[0])
	end


	def self.ccw_triangle?(p0, p1, p2)
	  tri_area2(p0, p1, p2) > 0
	end

	def self.cw_triangle?(p0, p1, p2)
	  tri_area2(p0, p1, p2) < 0
	end

    # Ear-Cut triangulation
    def self.ear_cutcw(verts)
      verts = verts.dup
      triangles = []
      loop_guard = 0

      while verts.size >= 3 && loop_guard < 1000
        loop_guard += 1
        ear_found = false
        edges = polygon_edges(verts)

        verts.each_with_index do |v, i|
          p0 = verts[i-1]
          p1 = v
          p2 = verts[(i+1) % verts.size]

          # On ne prend que les convexes
          next unless cw_triangle?(p0, p1, p2)

          # Vérifie qu'aucun autre point n'est dans le triangle
          next if verts.any? do |pt|
            pt != p0 && pt != p1 && pt != p2 && point_in_triangle?(pt, [p0,p1,p2])
          end

          # Vérifie que le triangle n'intersecte pas d'autres edges
          next if edges.any? do |a,b|
            ![p0,p1,p2].include?(a) && ![p0,p1,p2].include?(b) && segments_intersect?(p0,p2,a,b)
          end

          # Triangle valide
          triangles << [p0, p1, p2]
          verts.delete_at(i)
          ear_found = true
          break
        end

        break unless ear_found
      end

      # Ajouter le dernier triangle restant
      triangles << verts.dup if verts.size == 3
      triangles
    end


	def self.ear_cut(verts)
      triangles = []

      loop_guard = 0
      while verts.size >= 3 && loop_guard < 1000
        edges = polygon_edges(verts)
        loop_guard += 1
        ear_found = false

        verts.each_with_index do |v, i|
          p0 = verts[i-1]
          p1 = v
          p2 = verts[(i+1) % verts.size]

		  next unless ccw_triangle?(p0, p1, p2)

          next if verts.any? do |pt|
            pt != p0 && pt != p1 && pt != p2 &&
            point_in_triangle?(pt, [p0,p1,p2])
          end

          next if edges.any? do |a,b|
            ![p0,p1,p2].include?(a) &&
            ![p0,p1,p2].include?(b) &&
            segments_intersect?(p0,p2,a,b)
          end

          triangles << [p0,p1,p2]
          verts.delete_at(i)
          ear_found = true
          break
        end

        break unless ear_found
      end

      triangles << verts.dup if verts.size == 3
      triangles
	end

	def self.validate_loop(loop)
#	  puts "---- validate_loop ----"
#	  puts "nb verts: #{loop.size}"

#	  loop.each_cons(2).with_index do |(a,b),i|
#		if a == b
#		  puts "❌ doublon consécutif à #{i}: #{a}"
#		end
#	  end

#	  if loop.first == loop.last
#		puts "⚠️ loop fermé explicitement (first == last)"
#	  end

	  area = polygon_area(loop)
#	  puts "area = #{area} (#{area > 0 ? 'CCW' : 'CW'})"
	end


    def self.ear_cut_with_holes(verts, holes_triangles)
      triangles = []
      loop_guard = 0

      while verts.size >= 3 && loop_guard < 1000
        edges = polygon_edges(verts)
        loop_guard += 1
        ear_found = false

        verts.each_with_index do |v, i|
          p0 = verts[i-1]
          p1 = v
          p2 = verts[(i+1) % verts.size]
          
          tri = [p0,p1,p2]

          # Triangle doit être CCW
          # Vérifier convexité
          unless ccw_triangle?(p0,p1,p2)
#            puts "Rejeté (concave) : #{tri.map{|p| "[#{p[0]},#{p[1]}]"}.join(', ')}"
            next
          end
          
          # Vérifier intersection avec edges
          if edges.any? { |a,b| !tri.include?(a) && !tri.include?(b) && segments_intersect?(p0,p2,a,b) }
#            puts "Rejeté (intersection edges) : #{tri.map{|p| "[#{p[0]},#{p[1]}]"}.join(', ')}"
            next
          end
          
          # Vérifier qu’aucun autre point de la boucle ne soit dans le triangle
          # Vérifier qu’aucun point interne
          if verts.any? { |pt| pt != p0 && pt != p1 && pt != p2 && point_in_triangle?(pt, tri) }
#            puts "Rejeté (point interne) : #{tri.map{|p| "[#{p[0]},#{p[1]}]"}.join(', ')}"
            next
          end
          
          # Vérifier intersections avec edges existants


          # ✅ Vérifier qu’il n’intersecte pas un triangle de trou
          # Vérifier intersection avec triangles des trous
          if holes_triangles.any? { |hole_tri| triangle_intersect?(tri, hole_tri) }
#            puts "Rejeté (intersecte trou) : #{tri.map{|p| "[#{p[0]},#{p[1]}]"}.join(', ')}"
            next
          end

#          puts "Accepte : #{tri.map{|p| "[#{p[0]},#{p[1]}]"}.join(', ')}"

          # Ajouter le triangle valide
          triangles << [p0,p1,p2]
          verts.delete_at(i)
          ear_found = true
          break
        end

        break unless ear_found
      end

      triangles << verts.dup if verts.size == 3
      triangles
    end

    # -----------------------------
    # Triangulation principale
    # -----------------------------

	def self.tessellate(outer_loop, holes=[])
#		all holes triangles
		all_holes_triangles = []
		holes.each { |hole| 
		  all_holes_triangles.concat(ear_cutcw(hole))
		}
        allvert = bridge_holes(outer_loop, holes)
        triangles = ear_cut_with_holes(allvert, all_holes_triangles)
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
