require 'sketchup.rb'
require 'json'
require 'GNTools/Tools/GN_DefaultCNCData.rb'
require 'GNTools/Tools/GN_GCodeGenerate.rb'

Dir[File.join("GNTools/Tools/", "Paths", "*.rb")].each {|f| 
	puts f 
	require f  
}

module GNTools

	module Paths

		class LoopFace

		  attr_accessor :pfaces_vertices
		  attr_accessor :pfaces_normal

		  def initialize(faces = nil)
			@pfaces_vertices = []
			@pfaces_normal = []

			if faces
			  faces.each do |face|
				face_vertices = []
				face.outer_loop.vertices.each do |vertex|
				  face_vertices << vertex.position
				end
				@pfaces_vertices << face_vertices
				@pfaces_normal << face.normal
			  end
			end

			# Sous-modules internes
			@edge_offsetter   = EdgeOffsetter.new(self)
			@edge_intersector = EdgeIntersector.new(self)
			@loop_rebuilder   = LoopRebuilder.new(self)
		  end

		  # ------------------------------
		  # INTERFACE PUBLIQUE → inchangée
		  # ------------------------------
		  def deplacer(offset_distance)
			self.deplacer_arete(offset_distance)
		  end

		  def deplacer_arete(offset_distance)
			loop_arrays = []

			@pfaces_vertices.each_with_index do |pface, face_index|
			  # 1. Décalage des arêtes
			  moved_lines, edge_vectors = @edge_offsetter.process(pface, face_index, offset_distance)

			  # 2. Intersections & concavité
			  new_edges = @edge_intersector.process(moved_lines, edge_vectors)

			  # 3. Reconstruction des loops
			  loop_array = @loop_rebuilder.process(new_edges, face_index)
			  loop_arrays << loop_array
			end

			loop_arrays
		  end

		  # ========================================================
		  #  SOUS-CLASSE 1 : EdgeOffsetter
		  # ========================================================
		  class EdgeOffsetter
			def initialize(parent)
			  @parent = parent
			end

			def process(pface, face_index, offset_distance)
			  moved_lines = []
			  edge_vectors = []

			  pface.each_with_index do |start_pt, index|
				end_pt = pface[(index + 1) % pface.count]

				# Vecteur directionnel
				edge_vector = Geom::Vector3d.new(end_pt - start_pt)
				edge_vectors << edge_vector

				normal = @parent.pfaces_normal[face_index]

				# Décalage perpendiculaire
				offset_vector = normal.cross(edge_vector.normalize)
				offset_vector.length = -offset_distance

				new_start = start_pt + offset_vector
				new_end   = end_pt   + offset_vector

				moved_lines << [new_start, new_end]
			  end

			  [moved_lines, edge_vectors]
			end
		  end

		  # ========================================================
		  #  SOUS-CLASSE 2 : EdgeIntersector
		  # ========================================================
		  class EdgeIntersector
			def initialize(parent)
			  @parent = parent
			end

			def process(moved_lines, edge_vectors)
			  new_edges = []
			  inverse_edge = []

			  moved_lines.each_with_index do |line, i|
				next_line = moved_lines[(i + 1) % moved_lines.size]
				prev_line = moved_lines[(i - 1) % moved_lines.size]

				# Intersection début
				if line[0] != prev_line[1]
				  intersection_start = Geom.intersect_line_line(line, prev_line)
				else
				  intersection_start = line[0]
				end

				# Intersection fin
				if line[1] != next_line[0]
				  intersection_end = Geom.intersect_line_line(line, next_line)
				else
				  intersection_end = line[1]
				end

				if (intersection_end - intersection_start).normalize != edge_vectors[i].normalize
				  inverse_edge << i
				else
				  new_edges << [intersection_start, intersection_end]
				end
			  end

			  concavetest(new_edges)
			  new_edges
			end

			# --------------------------------------------------------
			# copie exacte de ton concavetest
			# --------------------------------------------------------
			def concavetest(new_edges)
			  index = 0
			  while index < new_edges.size
				edge_check = new_edges[index]
				index2 = index + 1

				while index2 < new_edges.size
				  other_edge = new_edges[index2]
				  intersection = Geom.intersect_line_line(edge_check, other_edge)

				  if intersection
					if pointOnEdge(edge_check, intersection) && pointOnEdge(other_edge, intersection)

					  new_edges.delete_at(index)
					  new_edges.insert(index, [edge_check[0], intersection], [intersection, edge_check[1]])

					  new_edges.delete_at(index2 + 1)
					  new_edges.insert(index2 + 1, [other_edge[0], intersection], [intersection, other_edge[1]])
					end
				  end

				  index2 += 1
				end

				index += 1
			  end
			end

			def pointOnEdge(edge, intersection)
			  intersect_edge_vector = (edge[1] - intersection)
			  intersect_edge_vector_length = intersect_edge_vector.length

			  edge_vector = (edge[1] - edge[0])

			  if (intersect_edge_vector.normalize == edge_vector.normalize)
				if intersect_edge_vector_length > 0 && intersect_edge_vector_length < edge_vector.length
				  return true
				end
			  end
			  false
			end
		  end

		  # ========================================================
		  #  SOUS-CLASSE 3 : LoopRebuilder
		  # ========================================================
		  class LoopRebuilder
			def initialize(parent)
			  @parent = parent
			end

			def process(new_edges, face_index)
			  @loop_array = []
			  loop = []

			  new_edges.each do |edge|
				loop << edge[0]
			  end

			  original_direction = loop_direction(@parent.pfaces_vertices[face_index])

			  @loop_array << get_loop_recursif(loop)

			  index_loop = 0
			  while index_loop < @loop_array.size
				if @loop_array[index_loop].size > 0
				  loop_direction_val = loop_direction(@loop_array[index_loop])

				  if (original_direction > 0) != (loop_direction_val > 0)
					@loop_array.delete_at(index_loop)
				  else
					index_loop += 1
				  end
				else
				  index_loop += 1
				end
			  end

			  @loop_array
			end

			# --------------------------------------------------------
			# copie exacte de tes fonctions
			# --------------------------------------------------------

			def get_loop_recursif(loop_recur)
			  index_loop = 0
			  while index_loop < loop_recur.size
				point = loop_recur[index_loop]

				if loop_recur.count(point) > 1
				  loop_index = loop_recur.each_index.select { |i| loop_recur[i] == point }

				  if loop_index.size == 2
					sliced_array = loop_recur.slice!(loop_index.min, (loop_index.max - loop_index.min))
					@loop_array << get_loop_recursif(sliced_array)
				  else
					puts "grandeur est plus grand que 2 %d" % loop_index.size
				  end

				  index_loop = 0
				else
				  index_loop += 1
				end
			  end
			  loop_recur
			end

			def loop_direction(old_edges)
			  sum_direction = 0
			  (0..old_edges.size).each do |i|
				edge1 = old_edges[(i) % old_edges.size]
				edge2 = old_edges[(i + 1) % old_edges.size]
				edge3 = old_edges[(i + 2) % old_edges.size]

				sum_direction += (edge2[0] - edge1[0]) * (edge3[1] - edge1[1]) -
								 (edge2[1] - edge1[1]) * (edge3[0] - edge1[0])
			  end
			  sum_direction
			end
		  end
		end


		class TransformPoint
			def self.getGlobalPoint(entity,point)
			  transformation = Geom::Transformation.new
			  parent = entity.parent
			  while parent
				if parent.is_a?(Sketchup::Group) || parent.is_a?(Sketchup::ComponentInstance)
				  # Si c'est un groupe ou une instance de composant, applique sa transformation
				  transformation *= parent.transformation
				  parent = parent.parent
				elsif parent.is_a?(Sketchup::ComponentDefinition)
				  # Si c'est une définition de composant, remonter encore plus haut
				  parent = parent.instances[0]
				else
				  # Si on atteint un parent non pertinent, sortir de la boucle
				  break
				end
			  end
			  return point.transform! transformation

			end
			
			def self.getGlobalTransform(entity)
			  transformation = Geom::Transformation.new
			  parent = entity
			  while parent
				if parent.is_a?(Sketchup::Group) || parent.is_a?(Sketchup::ComponentInstance)
				  # Si c'est un groupe ou une instance de composant, applique sa transformation
				  transformation *= parent.transformation
				  parent = parent.parent
				elsif parent.is_a?(Sketchup::ComponentDefinition)
				  # Si c'est une définition de composant, remonter encore plus haut
				  parent = parent.instances[0]
				else
				  # Si on atteint un parent non pertinent, sortir de la boucle
				  break
				end
			  end
			  transformation
			end


		end



		@@groupobj = {
			"Hole" => "Hole",
			"StraitCut" => "StraitCut",
			"Pocket" => "Pocket"
		}


		def self.loadPaths
			model = Sketchup.active_model
			model.entities.each {|ent|
				recursiveLoadPaths(ent)
			}
			nil
		end

		def self.recursiveLoadPaths(ent)
			newPath = createFromEnt(ent)
			if newPath == nil
				if ent.is_a?Sketchup::Group
					ent.entities.each { |entRecusive|
						recursiveLoadPaths(entRecusive)
					}
				end
			end
		end

		def self.isGroupObj(ent)
			groupObjName = nil
			if ent.typename == "Group"
				if ent.attribute_dictionaries  != nil
					if (ent.attribute_dictionaries.count == 1)
						ent.attribute_dictionaries.each {|dictionary| 
							groupObjName = dictionary.name
						}
					end
				end
			end
			if (@@groupobj.has_key?(groupObjName))
				return groupObjName
			else
				return nil
			end
		end # isGroupObj
			
		#GNTools::Paths.createFromEnt(ent)
		def self.createFromEnt(ent)
			groupName = isGroupObj(ent)
			case groupName
			when "Hole"
				pathObj = Paths::Hole.new(ent)
				return pathObj
			when "StraitCut"
				pathObj = Paths::StraitCut.new(ent)
				return pathObj
			when "Pocket"
				pathObj = Paths::Pocket.new(ent)
				return pathObj
			end
			return nil
		end

	end # module Paths
end  #module GNTools
