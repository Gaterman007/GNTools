require_relative "GN_Face.rb"

module GNTools

  EPSILON = 1e-6
  module Geometry
  
	class Point
	  attr_reader :x, :y, :z

	  def initialize(arr)
		@x, @y, @z = arr.map(&:to_f)
	  end
	  
	  # Point - Point => Vector
	  def -(p)
		Vector.new([
		  x - p.x,
		  y - p.y,
		  z - p.z
		])
	  end

	  # Point + Vector => Point
	  def +(v)
		Point.new([
		  x + v.x,
		  y + v.y,
		  z + v.z
		])
	  end

	  def to_vector
		Vector.new([x, y, z])
	  end
	  
	  def to_a
		[x, y, z]
	  end
	  
      def to_s
        format("Point(%.6f, %.6f, %.6f)", x, y, z)
      end
	end

	class Vector < Point
	  # Vector + Vector
	  def +(v)
		Vector.new([x + v.x, y + v.y, z + v.z])
	  end

	  # Vector - Vector
	  def -(v)
		Vector.new([x - v.x, y - v.y, z - v.z])
	  end

	  # Vector * scalar
	  def *(s)
		Vector.new([x * s, y * s, z * s])
	  end
	  def /(s)
		raise ZeroDivisionError if s.zero?
		Vector.new([x / s, y / s, z / s])
	  end
  
	  def cross(v)
		Vector.new([
		  y * v.z - z * v.y,
		  z * v.x - x * v.z,
		  x * v.y - y * v.x
		])
	  end

	  def dot(v)
		x * v.x + y * v.y + z * v.z
	  end

	  def length
		Math.sqrt(x*x + y*y + z*z)
	  end

	  def normalize
		l = length
		return Vector.new([0,0,0]) if l.zero?
		Vector.new([x/l, y/l, z/l])
	  end
	end

	class Edge
	  attr_reader :a, :b

	  def initialize(a, b)
		@a, @b = a, b
	  end

	  def key
        pa = a.to_a
        pb = b.to_a
        (pa <=> pb) == -1 ? [pa, pb] : [pb, pa]
	  end
	  
	  def to_s
        "Edge(#{a} -> #{b})"
      end
	  
	end

	class Loop
	  attr_reader :vertices

	  def initialize(vertices)
		raise "Loop requires at least 3 vertices" if vertices.size < 3
		@vertices = vertices.dup
	  end

	  def edges
		vertices.each_cons(2).map { |a,b| Edge.new(a,b) } +
		  [Edge.new(vertices.last, vertices.first)]
	  end
	  
	  def signed_area(normal)
	    area = 0.0
	    origin = vertices.first

	    vertices.each_cons(2) do |a, b|
		  va = a - origin
		  vb = b - origin
		  area += va.cross(vb).dot(normal)
	    end

	    a = vertices.last - origin
	    b = vertices.first - origin
	    area += a.cross(b).dot(normal)

	    area * 0.5
	  end

	  def reverse!
	    @vertices.reverse!
	    self
	  end

	  def normal
	    n = Geom::Vector3d.new(0,0,0)

	    vertices.each_with_index do |v, i|
		  w = vertices[(i + 1) % vertices.size]
		  n.x += (v.y - w.y) * (v.z + w.z)
		  n.y += (v.z - w.z) * (v.x + w.x)
		  n.z += (v.x - w.x) * (v.y + w.y)
	    end

	    n.normalize
	  end

	  def centroid
	    acc = Vector.new([0, 0, 0])

	    vertices.each do |v|
		  acc += v.to_vector
	    end

	    acc / vertices.size
	  end
	  
	  def to_a
		vertices.map(&:to_a)
	  end
	  
      def to_s
        "Loop(vertices=#{vertices.size})"
      end
	end

	class BBox
	  attr_reader :min, :max

	  def self.from_points(pts)
		xs = pts.map(&:x)
		ys = pts.map(&:y)
		zs = pts.map(&:z)

		new(
		  Point.new([xs.min, ys.min, zs.min]),
		  Point.new([xs.max, ys.max, zs.max])
		)
	  end

	  def initialize(min, max)
		@min = min
		@max = max
	  end

	  def intersects?(other)
		!( other.max.x < min.x || other.min.x > max.x ||
		   other.max.y < min.y || other.min.y > max.y ||
		   other.max.z < min.z || other.min.z > max.z )
	  end
	  
	  def to_s
		"BBox(min=#{min}, max=#{max})"
	  end
    end

    class Solid
      attr_accessor :faces, :edges, :bbox

      def initialize(faces: [], edges: nil)
        @faces = faces
        @edges = edges || derive_edges
        @bbox  = compute_bbox
		@triangles_cache = nil
		@dirty = true
#	    debug_dump
      end

	  def self.from_hash(hash)
	    faces = hash["faces"].map do |f|
		  outerloop = Loop.new(f["outer_loop"].map { |v| Point.new(v) })
		  innerloops = []
		  f["inner_loops"].each do |l|
		    innerloops << Loop.new(l.map { |v| Point.new(v) })
		  end
		  Face.new(outer_loop: outerloop, inner_loops: innerloops, normal: f["normal"])
	    end
	    new(faces: faces)
	  end

      def to_hash
        {
          "faces" => faces.map(&:to_hash)
        }
      end

	  def invalidate!
	    @dirty = true
	  end

	  def triangulate!
	    @triangles_cache = []
	    faces.each do |face|
		  face.triangles.each do |tri|
		    @triangles_cache << {
			  pts: tri,
			  normal: face.normal
		  }
		  end
	    end

	    @dirty = false
	  end

	  def triangles
	    triangulate! if @dirty || @triangles_cache.nil?
	    @triangles_cache
	  end

	  def triangulate_outer_loop(vertices)
	    return [] unless vertices && vertices.size >= 3

	    tris = []
	    p0 = vertices[0]

	    (1...(vertices.size - 1)).each do |i|
		  tris << [p0, vertices[i], vertices[i + 1]]
	    end

	    tris
	  end

	  def draw(view)
	    return unless view

	    tri_pts     = []
	    tri_normals = []
	    edge_pts    = []

	    triangles.each do |t|
		  pts    = t[:pts]
		  normal = t[:normal]

		  t[:pts].each do |p|
		    tri_pts << Geom::Point3d.new(p.x, p.y, p.z)
		    tri_normals << normal
		  end
	    end

	    edges.each do |e|
		  edge_pts << Geom::Point3d.new(e.a.x, e.a.y, e.a.z)
		  edge_pts << Geom::Point3d.new(e.b.x, e.b.y, e.b.z)
	    end
		view.drawing_color = "lightgrey"
	    view.draw(GL_TRIANGLES, tri_pts, normals: tri_normals, depth: 2) unless tri_pts.empty?
		view.drawing_color = "black"
	    view.draw(GL_LINES, edge_pts, line_width: 1, depth: 2) unless edge_pts.empty?
	  end

	  def to_group(name: "Solid Preview")
	    model = Sketchup.active_model
	    entities = model.active_entities
	    group = entities.add_group
	    group.name = name
	    gents = group.entities

	    faces.each do |face|
		  # ----------------------------
		  # 1. Outer loop → face principale
		  # ----------------------------
		  outer_pts = face.outer_loop.vertices.map do |v|
		    Geom::Point3d.new(v.x, v.y, v.z)
		  end

		  su_face = gents.add_face(outer_pts)
		  next unless su_face && su_face.valid?

		  # ----------------------------
		  # 2. Inner loops → trous
		  # ----------------------------
		  face.inner_loops.each do |loop|
		    loop.vertices.each_cons(2) do |a, b|
			  gents.add_line(
			    Geom::Point3d.new(a.x, a.y, a.z),
			    Geom::Point3d.new(b.x, b.y, b.z)
			  )
		    end

		    # fermer la boucle
		    a = loop.vertices.last
		    b = loop.vertices.first
		    gents.add_line(
			  Geom::Point3d.new(a.x, a.y, a.z),
			  Geom::Point3d.new(b.x, b.y, b.z)
		    )
		  end

		  # ----------------------------
		  # 3. Orientation correcte
		  # ----------------------------
		  original_normal = Geom::Vector3d.new(
		    face.normal.x,
		    face.normal.y,
		    face.normal.z
		  )

		  if su_face.normal.dot(original_normal) < 0
		    su_face.reverse!
		  end
	    end

	    group

	  end

      # Extrude chaque face le long de sa normale
      # distance > 0 : extrusion “vers l’extérieur”
      # distance < 0 : extrusion “vers l’intérieur”
      # Extrusion d'une ou plusieurs faces avec fermeture du solide
	  def pushpull(distance, target_faces = nil)
	    target_faces ||= faces
	    # copie toutes les faces qui ne sont pas dans target_faces
		new_faces = faces.reject { |f| target_faces.include?(f) }

	    # construire un hash edge => faces pour repérer les connexions
	    edge_map = Hash.new { |h, k| h[k] = [] }
		
		faces.each do |f|
		  f.all_edges.each do |e|
			edge_map[e.key] << f
		  end
		end		

	    connected_faces = []

		moved_edges_map = {}  # edge => [faces affectées]

	    target_faces.each do |face|
		  # créer de nouveaux points extrudés
		  extruded_vertices = face.vertices.map do |v|
		    Point.new([
			  v.x + face.normal.x * distance,
			  v.y + face.normal.y * distance,
			  v.z + face.normal.z * distance
		    ])
		  end

		  new_loop = Loop.new(extruded_vertices)
		  new_faces << Face.new(
		    normal: face.normal.to_a,
		    loops: [new_loop]
	  	  )

		  # repérer les arêtes qui bougent
		  face.edges.each_with_index do |e, i|
			moved_edges_map[e.key] ||= []

			# toutes les faces connectées à cette arête sauf la face poussée
			edge_map[e.key].each do |f2|
			  next if target_faces.include?(f2)
			  moved_edges_map[e.key] << f2 unless moved_edges_map[e.key].include?(f2)
			end
		  end

	    end

	    puts "Edge connectées au pushpull : #{moved_edges_map.size}"

	    @faces = new_faces
	    @edges = derive_edges
	    @bbox  = compute_bbox
		invalidate!

	    [moved_edges_map,edge_map] # on pourrait les retourner pour tests
	  end

      private

	  def derive_edges
	    edges = {}
	    faces.each do |f|
		  f.all_edges.each do |e|
		    edges[e.key] ||= e
		  end
	    end
	    edges.values
	  end

      def compute_normal(p0, p1, p2)
        u = Vector.new([p1.x - p0.x, p1.y - p0.y, p1.z - p0.z])
        v = Vector.new([p2.x - p0.x, p2.y - p0.y, p2.z - p0.z])
        n = Vector.new([u.y*v.z - u.z*v.y,
                        u.z*v.x - u.x*v.z,
                        u.x*v.y - u.y*v.x])
        n.normalize.to_a
      end
	  
	  def compute_bbox
	    pts = faces.flat_map(&:all_vertices)
	    BBox.from_points(pts)
	  end
	  
	  def to_s
        "Solid(faces=#{faces.size}, edges=#{edges.size}, bbox=#{bbox})"
      end
	  
	  def debug_dump

		puts "Solid:"
		puts "  faces: #{@faces.size}"

		@faces.each_with_index do |f, i|
		  if f.inner_loops and f.inner_loops.size > 0
			  puts "  Face #{i}:"
			  puts "    normal: #{f.normal.to_s}"
			  puts "    outer_loop pts: #{f.outer_loop.vertices.size}"
			  puts "       				#{f.outer_loop.vertices}"
			  puts "    inner_loops: #{f.inner_loops.size}" if f.inner_loops
			  f.inner_loops.each {|innerloop|
				puts "       				#{innerloop.vertices}"
			  }
		  end
		end
	  end
	  
    end
	
  end
end
