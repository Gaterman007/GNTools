require 'sketchup.rb'
require 'json'
require 'GNTools/GN_DefaultCNCData.rb'
require 'GNTools/GN_GCodeGenerate.rb'

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
			end

			def pointOnEdge(edge,intersection)
				intersect_edge_vector = (edge[1] - intersection)
				intersect_edge_vector_length = intersect_edge_vector.length
				edge_vector = (edge[1] - edge[0])
				if (intersect_edge_vector.normalize == edge_vector.normalize)
					if  (intersect_edge_vector_length > 0 &&intersect_edge_vector_length <edge_vector.length)
						return true
					end
				end
				return false
			end

			def deplacer_arete(offset_distance)
				loop_arrays = []

#				transformation = GNTools::Paths::TransformPoint.getGlobalTransform(@pathEntitie)
				@pfaces_vertices.each_with_index do |pface,face_index|
					edge_vectors = []
					new_edges = []
					inverse_edge = []
					moved_lines = []
					pface.each_with_index do |start_pt,index|
						end_pt = pface[(index + 1) % pface.count]
#						start_pt = start_pt.transform! transformation
#						end_pt = end_pt.transform! transformation
				# Vecteur directionnel de l'arête
						edge_vector = Geom::Vector3d.new(end_pt - start_pt)
						edge_vectors << edge_vector
						normal = @pfaces_normal[face_index]
		  # Produit vectoriel pour obtenir un vecteur perpendiculaire dans le plan
						offset_vector = normal.cross(edge_vector.normalize)
						offset_vector.length = -offset_distance  # Ajustement à la dist.normalizeace voulue

				# Déplacer le segment entier
						new_start = start_pt + offset_vector
						new_end = end_pt + offset_vector
						moved_lines << [new_start, new_end]  # On stocke la ligne décalée
					end
			  # replace les debut et fin pour fermer 
					moved_lines.each_with_index do |line, i|
						next_line = moved_lines[(i + 1) % moved_lines.size]  # Ligne suivante (boucle fermée)
						prev_line =  moved_lines[(i - 1) % moved_lines.size]  # Ligne precedente (boucle fermée)
						if line[0] != prev_line[1]  # le debut de la ligne n est pas la fin de la precedente
							intersection_start = Geom.intersect_line_line(line, prev_line)
							if intersection_start == nil # la ligne precedente est sur la meme droite
								puts "c est comme impossible ?"  # comment deux ligne qui ne sont pas sur la meme droite peut ne pas intesecter
							end
						else # la ligne precedente est sur la meme droite et le debut est le fin de la ligne
							intersection_start = line[0]
						end
						if line[1] != next_line[0]  # le fin de la ligne n est pas la debut de la prochaine
							intersection_end = Geom.intersect_line_line(line, next_line)
							if intersection_end == nil  # la ligne suivante est sur la meme droite ?
								puts "c est comme impossible ?" # comment deux ligne qui ne sont pas sur la meme droite peut ne pas intesecter
							end
						else   # la ligne suivante est sur la meme droite et la fin est le debut de la suivante
							intersection_end = line[1]
						end
						if (intersection_end - intersection_start).normalize != edge_vectors[i].normalize
							inverse_edge << i
						else
							new_edges << [intersection_start,intersection_end]
						end
					end
					self.concavetest(new_edges)
					loop_array = self.get_loops(new_edges,face_index)
					loop_arrays << loop_array
				end
				loop_arrays
			end

			def concavetest(new_edges) 
				index = 0
				while index < new_edges.size
					edge_check = new_edges[index]
					index2 = index + 1
					edge_split = false
					while index2 < new_edges.size
						other_edge = new_edges[index2]
						intersection = Geom.intersect_line_line(edge_check, other_edge)
						if intersection
		#              intersect_vector = (edge[1] - intersection)
							intersect_other_edge_vector = (other_edge[1] - intersection)
							other_edge_vector = (other_edge[1] - other_edge[0])
							if pointOnEdge(edge_check,intersection) && pointOnEdge(other_edge,intersection)
					# replace edge_check avec [edge_check[0], intersection] et [intersection, edge_check[1]]
								new_edges.delete_at(index)
								new_edges.insert(index,[edge_check[0],intersection],[intersection, edge_check[1]])
					# replace other_edge avec [other_edge[0], intersection] et [intersection, other_edge[1]]
								new_edges.delete_at(index2+1)
								new_edges.insert(index2+1,[other_edge[0],intersection],[intersection, other_edge[1]])
								edge_split = true
							end
						end  
						index2 += 1
					end  
					index += 1  # Incrémentation normale
				end
			end

			def get_loop_recursif(loop_recur)
				index_loop = 0
				while index_loop < loop_recur.size
					point = loop_recur[index_loop]
					if loop_recur.count(point) > 1
						loop_index = loop_recur.each_index.select {|i| loop_recur[i] == point}
						if loop_index.size == 2
							sliced_array = loop_recur.slice!(loop_index.min,(loop_index.max - loop_index.min))
							@loop_array << self.get_loop_recursif(sliced_array)
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
		  
			def get_loops(new_edges,face_index)
				@loop_array = []
				loop = []
				new_edges.each do |edge|
					loop << edge[0]
				end
				original_direction = self.loop_direction(self.pfaces_vertices[face_index])
				@loop_array << self.get_loop_recursif(loop)
				index_loop = 0
				while index_loop < @loop_array.size
					if @loop_array[index_loop].size > 0
						loop_direction = self.loop_direction(@loop_array[index_loop])  
						if (original_direction > 0) != (loop_direction > 0)
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

			def loop_direction(old_edges) 
				sum_direction = 0
				(0..old_edges.size).each do |index_horaire|
					edge1 = old_edges[(index_horaire) % old_edges.size]
					edge2 = old_edges[(index_horaire + 1) % old_edges.size]
					edge3 = old_edges[(index_horaire + 2) % old_edges.size]
					sum_direction += (edge2[0] - edge1[0]) * (edge3[1] - edge1[1]) - (edge2[1] - edge1[1]) * (edge3[0] - edge1[0])
				end
				sum_direction
			end
		  
		  
			def deplacer(offset_distance)
				loop_arrays = self.deplacer_arete(offset_distance)
				loop_arrays
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

		#GNTools::Paths::PathObjObserver.add_group(path_obj)

		class PathObjObserver < Sketchup::EntityObserver

			def self.add_group(path_obj)
				if path_obj
					path_obj.pathEntitie.add_observer(PathObjObserver.new(path_obj))
				end
			end
		
			def initialize(path_obj)
				super()
				@path_obj = path_obj  # Garde une référence vers l'instance complète
				@group = path_obj.pathEntitie
			end

			def onChangeEntity(entity)
				if @group.valid?
#					puts "PathObjObserver.onChangeEntity #{@group} #{@path_obj.pathName}"
					@path_obj.changed()
#				else # va passer par onEraseEntity
#					puts "PathObjObserver.onChangeEntity deleted #{@group} #{@path_obj.pathName}"
				end
			end

			def onEraseEntity(entity)
				if !@group.valid?  #ne devrait jamais etre valid car deja effacer
#					puts "PathObjObserver.onEraseEntity #{@group} #{@path_obj.pathName}"
#				else
#					puts "PathObjObserver.onEraseEntity deleted #{@group} #{@path_obj.pathName}"
					GNTools.pathObjList.delete(@path_obj.pathID)
					@path_obj = nil
				end
			end
		end


		class PathObj
			attr_accessor :pathEntitie
			attr_accessor :pathID
			attr_accessor :pathName
			attr_accessor :drillBitName
			attr_accessor :methodType
			attr_accessor :depth
			attr_accessor :feedrate
			attr_accessor :multipass
			attr_accessor :depthstep
			attr_accessor :overlapPercent

			@@defaultType = {
								"pathName":"",
								"dictionaryName":"",
								"drillBitName":"Default",
								"methodType":"",
								"depth":4.0,
								"feedrate":5.0,
								"multipass":true,
								"depthstep":0.2,
								"overlapPercent":50
							}
			
			def initialize(pathObjType,group)
				@pathName = ""
				@dictionaryName = pathObjType
				@drillBitName = "Default"
				@methodType = ""
				@depth = 4
				@feedrate = 5
				@multipass = true
				@depthstep = 0.2
				@overlapPercent = 50
				if group				# group != nil  peut etre 0 ou peut etre un group
					if group == 0		# group = 0		cree sans group car utiliser pour sauver donner seulement
						self.pathEntitie = nil					
					else				# group   aller chercher dans le group les infos
						self.pathEntitie = group
						self.get_From_Attributs(group)
					end
				else					# group == nil	cree avec les infos par defaut
					self.pathEntitie = Sketchup.active_model.active_entities.add_group()
					self.set_To_Attribute(self.pathEntitie)
				end
			end

		    def defaultType
			  @@defaultType
		    end

			def pathEntitie
				@pathEntitie
			end
			
			def pathEntitie=(group)
				if group
					@pathEntitie = group
					@pathID = group.persistent_id
					GNTools.pathObjList[group.persistent_id] = self
					GNTools::Paths::PathObjObserver.add_group(self)
				else
					@pathEntitie = nil
					@pathID = nil
				end
			end

			def pathName
				@pathName
			end
			
			def pathName=(v)
				@pathName = v
				if @pathEntitie
					@pathEntitie.name = v
				end
			end

		    # Accéder à la variable d'instance
		    def [](key)
			  # On utilise `instance_variable_get` pour récupérer la valeur de la variable d'instance
			  if @pathEntitie
				@pathEntitie.get_attribute( @dictionaryName,"#{key}" )
			  else
			    instance_variable_defined?("@#{key}") ? instance_variable_get("@#{key}") : nil
			  end
		    end

		    # Modifier la variable d'instance
		    def []=(key, value)
			  if instance_variable_defined?("@#{key}") 
				  if !self.defaultType[key.to_sym].is_a?(String) #&& !self.defaultType[key.to_sym].is_a?(Array)
					  if value == nil
						if self.defaultType[key.to_sym].is_a?(Float)
						   value = 0.0
						elsif self.defaultType[key.to_sym].is_a?(Int)
						   value = 0
						end
					  end
				  end
			  end	
			  # On utilise `instance_variable_set` pour modifier la variable d'instance
			  instance_variable_set("@#{key}", value) if instance_variable_defined?("@#{key}")
		  
			  if @pathEntitie
				@pathEntitie.set_attribute( @dictionaryName,"#{key}", value )
				self.changed()
			  end
		    end

			def changed(create_undo = false)
				nil
			end
			def createEdge(group,start,finish)
				puts "edge %f,%f,%f : %f,%f,%f" % [start[0] , start[1], start[2], finish[0] , finish[1], finish[2]]
				edge = group.entities.add_edges(start,finish)
				@lastPosition = finish
			end
			
			def nextEdge(group,newPosition)
				puts "edge %f,%f,%f : %f,%f,%f" % [@lastPosition[0] , @lastPosition[1], @lastPosition[2], newPosition[0] , newPosition[1], newPosition[2]]
				edge = group.entities.add_edges(@lastPosition,newPosition)
				@lastPosition = newPosition
			end
			
			def nextEdgeXY(group,newXPosition,newYPosition)
				puts "edge %f,%f,%f : %f,%f,%f" % [@lastPosition[0] , @lastPosition[1], @lastPosition[2], newXPosition,newYPosition,@lastPosition[2]]
				edge = group.entities.add_edges(@lastPosition,[newXPosition,newYPosition,@lastPosition[2]])
				@lastPosition = [newXPosition,newYPosition,@lastPosition[2]]
			end

			def nextEdgeZ(group,newPosition)
				puts "edge %f,%f,%f : %f,%f,%f" % [@lastPosition[0] , @lastPosition[1], @lastPosition[2], @lastPosition[0],@lastPosition[1],newPosition]
				edge = group.entities.add_edges(@lastPosition,[@lastPosition[0],@lastPosition[1],newPosition])
				@lastPosition = [@lastPosition[0],@lastPosition[1],newPosition]
			end

			def createPath()
				nil
			end
			
			def set_To_Attribute(group)
				group.set_attribute( @dictionaryName,"drillBitName", @drillBitName )
				group.set_attribute( @dictionaryName,"methodType", @methodType )
				group.set_attribute( @dictionaryName,"depth", @depth )
				group.set_attribute( @dictionaryName,"feedrate", @feedrate )
				group.set_attribute( @dictionaryName,"depthstep", @depthstep )
				group.set_attribute( @dictionaryName,"multipass", @multipass )
				group.set_attribute( @dictionaryName,"overlapPercent",@overlapPercent )
			end
			
			def get_From_Attributs(group)
				@pathEntitie = group
				@pathName = group.name
				@depth = group.get_attribute( @dictionaryName,"depth" )
				@methodType = group.get_attribute( @dictionaryName,"methodType" )
				@feedrate = group.get_attribute( @dictionaryName,"feedrate" )
				@depthstep = group.get_attribute( @dictionaryName,"depthstep" )
				@multipass = group.get_attribute( @dictionaryName,"multipass" )
				@overlapPercent = group.get_attribute( @dictionaryName,"overlapPercent" )
				@drillBitName = group.get_attribute( @dictionaryName,"drillBitName" )
			end
			
			def from_Hash(hash)
				self.drillBitName = hash["drillBitName"]["Value"] || ""
				self.depth = hash["depth"]["Value"] || 0
				self.methodType = hash["methodType"]["Value"] || ""
				self.feedrate = hash["feedrate"]["Value"] || 0
				self.overlapPercent = hash["overlapPercent"]["Value"] || 0
				self.depthstep = hash["depthstep"]["Value"] || 0
				if hash["multipass"]["Value"]
					self.multipass = true
				else
					self.multipass = false
				end
			end
			
			def to_Hash(hashTable)
				hashTable["drillBitName"] = {"Value" => self["drillBitName"], "type" => "dropdown","multiple" => false}
				hashTable["depth"] = {"Value" => self["depth"], "type" => "spinner","multiple" => false}
				hashTable["methodType"] = {"Value" => self["methodType"], "type" => "dropdown","multiple" => false}
				hashTable["feedrate"] = {"Value" => self["feedrate"], "type" => "spinner","multiple" => false}
				hashTable["overlapPercent"] = {"Value" => self["overlapPercent"], "type" => "spinner","multiple" => false}
				hashTable["depthstep"] = {"Value" => self["depthstep"], "type" => "spinner","multiple" => false}
				hashTable["multipass"] = {"Value" => self["multipass"], "type" => "multipass","multiple" => false}
				hashTable
			end
		end

	end # module Paths
end  #module GNTools
