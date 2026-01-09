module GNTools
  module Geometry
	class Point
	  attr_reader :x, :y, :z

	  def initialize(arr)
		@x, @y, @z = arr.map(&:to_f)
	  end

	  def to_a
		[x, y, z]
	  end
	  
      def to_s
        format("Point(%.6f, %.6f, %.6f)", x, y, z)
      end
	end

	class Vector < Point
	  def dot(v)
		x*v.x + y*v.y + z*v.z
	  end

	  def normalize
		l = Math.sqrt(dot(self))
		Vector.new([x/l, y/l, z/l]) if l > 0
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
		@vertices = vertices
	  end

	  def edges
		vertices.each_cons(2).map { |a,b| Edge.new(a,b) } +
		  [Edge.new(vertices.last, vertices.first)]
	  end

	  def closed?
		vertices.first.to_a == vertices.last.to_a
	  end

	  def to_a
		vertices.map(&:to_a)
	  end
	  
      def to_s
        "Loop(vertices=#{vertices.size})"
      end
	end

    class Face
      attr_reader :normal, :loops

      def initialize(normal:, loops:)
        @normal = Vector.new(normal)
        @loops  = loops
      end

      def outer_loop
        loops.first
      end

      def inner_loops
        loops[1..] || []
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

      def to_hash
        {
          "normal" => normal.to_a,
          "outer_loop" => outer_loop.to_a,
          "inner_loops" => inner_loops.map(&:to_a)
        }
      end

      def to_s
        "Face(loops=#{loops.size}, normal=#{normal})"
      end
    end

    class Solid
      attr_accessor :faces, :edges, :bbox

      def initialize(faces: [], edges: nil)
        @faces = faces
        @edges = edges || derive_edges
        @bbox  = compute_bbox
      end

	  def self.from_hash(hash)
	    faces = hash["faces"].map do |f|
		  loops = []
		  loops << Loop.new(f["outer_loop"].map { |v| Point.new(v) })
		  f["inner_loops"].each do |l|
		    loops << Loop.new(l.map { |v| Point.new(v) })
		  end
		  Face.new(normal: f["normal"], loops: loops)
	    end
	    new(faces: faces)
	  end

      def to_hash
        {
          "faces" => faces.map(&:to_hash)
        }
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
  end
end