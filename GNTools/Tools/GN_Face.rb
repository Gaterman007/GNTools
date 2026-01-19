module GNTools
  EPSILON = 1e-6
  module Tessellator

    # =========================================================
    # Géométrie 2D bas niveau
    # =========================================================
    module Geom2D
      EPS = GNTools::EPSILON

      def self.area2(a,b,c)
        (b[0]-a[0])*(c[1]-a[1]) -
        (b[1]-a[1])*(c[0]-a[0])
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
        return false if collinear?(a,b,c) && collinear?(a,b,d)

        ccw?(a,c,d) != ccw?(b,c,d) &&
        ccw?(a,b,c) != ccw?(a,b,d)
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
        w1 = Geom2D.area2(p,a,b)
        w2 = Geom2D.area2(p,b,c)
        w3 = Geom2D.area2(p,c,a)

        if strict
          w1 > Geom2D::EPS &&
          w2 > Geom2D::EPS &&
          w3 > Geom2D::EPS
        else
          has_pos = w1 > 0 || w2 > 0 || w3 > 0
          has_neg = w1 < 0 || w2 < 0 || w3 < 0
          !(has_pos && has_neg)
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

    # =========================================================
    # Outils polygone
    # =========================================================
    def self.polygon_edges(loop)
      loop.each_cons(2).map { |a,b| [a,b] } +
      [[loop.last, loop.first]]
    end
    
    def self.distance2(a,b)
      dx = a[0]-b[0]; dy = a[1]-b[1]; dx*dx + dy*dy
    end
    
    def self.polygon_area(loop)
      loop.each_with_index.sum do |p,i|
        q = loop[(i+1)%loop.size]
        (p[0]*q[1] - q[0]*p[1])
      end * 0.5
    end

    def self.ensure_ccw(loop)
      polygon_area(loop) < 0 ? loop.reverse : loop
    end

    def self.cleanup_degenerate_vertices!(verts)
      i = 0
      while i < verts.size && verts.size > 3
        a = verts[(i-1)%verts.size]
        b = verts[i]
        c = verts[(i+1)%verts.size]

        if a == b || b == c || Geom2D.collinear?(a,b,c)
          verts.delete_at(i)
        else
          i += 1
        end
      end
    end

    # =========================================================
    # Test intersection triangle / triangle
    # =========================================================
    def self.triangle_intersect?(a,b)
      a.any? { |pt| Triangle2D.contains_point?(b, pt, strict: true) } ||
      b.any? { |pt| Triangle2D.contains_point?(a, pt, strict: true) } ||
      Triangle2D.edges(a).any? { |e|
        Triangle2D.edges(b).any? { |f|
          Geom2D.segments_intersect_strict?(e[0],e[1],f[0],f[1])
        }
      }
    end

	def self.segment_crosses_hole?(p, q, hole_tris)
	  hole_tris.any? do |tri|
		Triangle2D.intersects_segment?(tri, p, q)
	  end
	end
    
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

    # =========================================================
    # Ear clipping générique (avec trous)
    # =========================================================
    def self.ear_cut(verts, ccw: true, forbidden_tris: [])
      verts = verts.dup
      triangles = []

      while verts.size >= 3
        ear_found = false

        verts.each_with_index do |p1,i|
          p0 = verts[i-1]
          p2 = verts[(i+1)%verts.size]

          ok_orient = ccw ?
            Geom2D.ccw?(p0,p1,p2) :
            Geom2D.cw?(p0,p1,p2)
          next unless ok_orient

          tri = [p0,p1,p2]

          next if verts.any? { |pt|
            !tri.include?(pt) &&
            Triangle2D.contains_point?(tri, pt)
          }

          next if forbidden_tris.any? { |t|
            triangle_intrudes?(tri, t)
          }

          triangles << tri
          verts.delete_at(i)
          cleanup_degenerate_vertices!(verts)
          ear_found = true
          break
        end

        break unless ear_found
      end

      triangles << verts if verts.size == 3
      triangles
    end

    def self.bridge_holes(outer, holes)
      loop = outer.dup

      # 1️⃣ Pré-calcul : trianguler chaque trou pour tester les intersections
      hole_triangles = {}
      holes.each do |hole|
        hole_triangles[hole] = ear_cut(hole, ccw: false)
      end

      holes.each do |hole|
        bridge_found = false

        # Essayer tous les points du trou
        hole.each_with_index do |h, hole_index|
          loop_edges = polygon_edges(loop)

          # Essayer tous les points du loop
          candidates = loop.each_with_index.select do |p, i|
            # Pas d'intersection avec le loop courant
            next false if loop_edges.any? { |a,b|
              ![a,b].include?(p) && Geom2D.segments_intersect_strict?(h,p,a,b)
            }

            # Pas d'intersection avec les autres trous
            next false if holes.any? do |other_hole|
              next false if other_hole == hole
              segment_crosses_hole?(h, p, hole_triangles[other_hole])
            end
            
            # Pas d'intersection avec son propre trou (sauf aux extrémités)
            hole_edges = polygon_edges(hole)
            next false if hole_edges.any? { |a,b|
              ![h].include?(a) && ![h].include?(b) && Geom2D.segments_intersect_strict?(h,p,a,b)
            }

            true
          end

          if candidates.any?
            # Choisir le point le plus proche
            outer_index = candidates.min_by { |p,i| distance2(h,p) }[1]

            # Reconstruire le trou dans le bon ordre
            hole_path = []
#            hole.size.times do |i|
#              hole_path << hole[(hole_index - i) % hole.size]  # ⬅️ sens inversé
#            end
            
            hole.size.times { |i| hole_path << hole[(hole_index + i) % hole.size] }
#            hole_path << hole_path.first  # fermer le trou

#            loop = loop[0..outer_index] + hole_path + [hole_path.first] + loop[outer_index..-1]


            # Insérer le bridge dans le loop
            hole_path << hole_path.first  # fermer le trou
            loop = loop[0..outer_index] + hole_path + loop[outer_index..-1]

            bridge_found = true
            break
          end
        end
      
        # Si aucun bridge valide n'a été trouvé, lever une exception
        raise "❌ aucun bridge valide trouvé pour ce trou" unless bridge_found
      end

      loop
    end

    # =========================================================
    # API principale
    # =========================================================
    def self.tessellate(outer, holes=[])
      outer = ensure_ccw(outer)

      hole_tris = holes.flat_map do |h|
        ear_cut(h, ccw: false)
      end

      merged = bridge_holes(outer, holes)
      ear_cut(merged, ccw: true, forbidden_tris: hole_tris)
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
#      puts "outer_loop = ["
#      data[:outer].each { |p| puts "  #{p}," }
#      puts "]"

#      puts "holes = ["
#      data[:holes].each do |hole|
#        puts "  ["
#        hole.each { |p| puts "    #{p}," }
#        puts "  ],"
#      end
#      puts "]"

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
