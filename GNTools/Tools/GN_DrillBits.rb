require 'sketchup.rb'
require 'json'

module GNTools

	#a drill bit information
	class DrillBit
	
		attr_accessor :name
		attr_accessor :cut_Types
		attr_accessor :cut_Diameter
		attr_accessor :units
		attr_accessor :cutting_Length
		attr_accessor :drill_Size
		attr_accessor :shank_Height
		attr_accessor :shank_Diam
		attr_accessor :shoulder_Lenght
		attr_accessor :number_of_Flutes
		attr_accessor :cutting
		attr_accessor :tool_profile

		def initialize(name = "", cut_Types = "", cut_Diameter = 4,units = "mm",cutting_Length = 5,drill_Size = 1,shank_Height = 1,shank_Diam = 1,shoulder_Lenght = 1,number_of_Flutes = 1,cutting = 1,profil = nil)
			@name = name
			@cut_Types = cut_Types
			@cut_Diameter = cut_Diameter
			@units = units
			@cutting_Length = cutting_Length
			@drill_Size = drill_Size
			@shank_Height = shank_Height
			@shank_Diam = shank_Diam
			@shoulder_Lenght = shoulder_Lenght
			@number_of_Flutes = number_of_Flutes
			@cutting = cutting
			if profil
			  @tool_profile = profil
#			  puts "init tool_profile #{@tool_profile}"
			else
			  @tool_profile = generate_flat_profile
#			  puts "init tool_profile #{@tool_profile}"
			end
		end

		def from_Hash(hash)
			@name = hash["Name"]
			@cut_Types = hash["Cut_Types"]
			@cut_Diameter = hash["Cut_Diameter"]
			@units = hash["units"]
			@cutting_Length = hash["Cutting_Length"]
			@drill_Size = hash["Drill_Size"]
			@shank_Height = hash["Shank_Height"]
			@shank_Diam = hash["Shank_Diam"]
			@shoulder_Lenght = hash["Shoulder_Lenght"]
			@number_of_Flutes = hash["Number_of_Flutes"]
			@cutting = hash["Cutting"]
			@tool_profile = hash["Tool_Profile"] || generate_flat_profile
#			puts "hash tool_profile #{@tool_profile}"
		end

		def key(p)
		  [p.x.to_f.round(8), p.y.to_f.round(8), p.z.to_f.round(8)]
		end

		def ordered_points_from_edges(edges)
		  return [] if edges.empty?

		  # Construire la connectivité vertex => edges
		  start_edges = Hash.new { |h, k| h[k] = [] }
		  end_edges = Hash.new { |h, k| h[k] = [] }
		  edges.each do |e|
			start_edges[e.start] << e
			end_edges[e.end] << e
		  end
		  start_vertex = start_edges.find { |v, es| es.length == 1 }&.first

		  # Trouver un sommet de départ (open loop)
		  start_vertex = vertex_edges.find { |v, es| es.length == 1 }&.first
		  return [] unless start_vertex

		  ordered_points = []
		  used_edges = {}

		  current_vertex = start_vertex
		  start_edge = vertex_edges[current_vertex]
		  current_edge = start_edge

		  loop do
		  
		    current_edge.end
			
			ordered_points << current_vertex.position

			# trouver la prochaine edge non utilisée
			next_edge = vertex_edges[current_vertex].find { |e| !used_edges[e] }
			
			break unless next_edge

			used_edges[next_edge] = true

			# avancer vers l'autre sommet
			current_vertex =
			  (next_edge.start == current_vertex) ? next_edge.end : next_edge.start
		  end

		  ordered_points
		end


		def profile_from_geometry(group_or_array)
		  edges =
			case group_or_array
			when Sketchup::Group
			  group_or_array.entities.grep(Sketchup::Edge)
			when Array
			  if group_or_array.length == 1 and group_or_array[0].is_a?(Sketchup::Group)
			    group_or_array[0].entities.grep(Sketchup::Edge)
			  else
			    group_or_array.grep(Sketchup::Edge)
			  end
			else
			  return []
			end

		  return [] if edges.empty?
  
		  pts3d = ordered_points_from_edges(edges)
		  return [] if pts3d.empty?

		  # Projection XZ
		  #profile = pts3d.map { |p| [p.x, p.z] }

		  profile = pts3d.map do |p|
		    x = p.x.to_f    # float en pouces
		    z = p.z.to_f
		    [x, z]
		  end

		  # Sécurité
		  profile.select! { |x, z| x >= 0.0 }

		  # Normalisation : base à z = 0
		  min_z = profile.map(&:last).min
		  profile.map! { |x, z| [x, z - min_z] }

		  profile
		end

		def profile_to_group(tool_profile, name: "Tool Profile")
		  group = Sketchup.active_model.active_entities.add_group
		  group.name = name

#		  puts "profile_to_group tool_profile #{tool_profile}"
		  
		  
		  pts = tool_profile.map do |x, z|
			Geom::Point3d.new(x, 0, z)  # déjà en pouces
		  end
		  
		  pts.each_cons(2) do |p0, p1|
			group.entities.add_line(p0, p1)
		  end

		  group
		end

		def to_Json()
#			puts "json tool_profile #{@tool_profile}"
			json = JSON.generate({
				'Name' => @name,
				'Cut_Types' => @cut_Types,
				'Cut_Diameter' => @cut_Diameter,
				'units' => @units,
				'Cutting_Length' => @cutting_Length,
				'Drill_Size' => @drill_Size,
				'Shank_Height' => @shank_Height,
				'Shank_Diam' => @shank_Diam,
				'Shoulder_Lenght' => @shoulder_Lenght,
				'Number_of_Flutes' => @number_of_Flutes,
				'Cutting' => @cutting,
				'Tool_Profile' => @tool_profile
			})
#			puts "json #{json}"
			json
		end


		def generate_flat_profile
		  radius = @cut_Diameter.mm.to_f / 2.0
		  cutting_Length = @cutting_Length.mm.to_f
		  [
			[radius, 0.0],
			[0.0, 0.0],
			[0.0, cutting_Length]
		  ]
		end

		def saveToFile(file)
			file.write(self.to_Json)
			file.write("\n")
		end
		
		def loadFromFile(line)
			hash = JSON.parse(line)
			self.from_Hash(hash)
		end

	end

	# show drill bits dialog
	class DrillBits
	
		@@drillbitTbl = []
		@@drillbitSel = 0
		
		def self.drillbitSel
			@@drillbitSel
		end

		def self.drillbitTbl
			@@drillbitTbl
		end
		
		def self.show
			db = DrillBits.new
			db.show_dialog
		end
		
		def self.isDrillBit(name)
			drillBit = @@drillbitTbl.select{|drillBitObj| drillBitObj.name == name}
			drillBit
		end
		
		def self.getDrillBit(name)
			drillBit = @@drillbitTbl.select{|drillBitObj| drillBitObj.name == name}
			if (drillBit.size() == 0)
				@@drillbitTbl[0]
			else
				drillBit[0]
			end
		end
		
		
		def self.load_drillBitsTbl
			@@drillbitTbl.push(DrillBit.new("Default","Up"	,3.175,"mm"  ,10  ,3.175,22  ,3.175,0   ,2  ,0,nil))
			@@drillbitTbl.push(DrillBit.new("#2"	 ,"Up"	,3.175,"mm"  ,10  ,3.175,22  ,3.175,0   ,2  ,0,nil))
			@@drillbitTbl.push(DrillBit.new("#3"	 ,"Up"	,6	  ,"mm"  ,13  ,6    ,57  ,6    ,0   ,4  ,0,nil))
			@@drillbitTbl.push(DrillBit.new("#4"	 ,"Up"	,5.5  ,"mm"  ,13  ,6    ,57  ,6    ,0   ,4  ,0,nil))
			@@drillbitTbl.push(DrillBit.new("#5"	 ,"Up"	,5 	  ,"mm"  ,13  ,6    ,57  ,6    ,0   ,4  ,0,nil))
			@@drillbitTbl.push(DrillBit.new("#6"	 ,"Up"	,4.5  ,"mm"  ,12  ,6    ,56  ,6    ,0   ,4  ,0,nil))
			@@drillbitTbl.push(DrillBit.new("#7"	 ,"Up"	,4	  ,"mm"  ,11  ,6    ,55  ,6    ,0   ,4  ,0,nil))
			@@drillbitTbl.push(DrillBit.new("#8"	 ,"Up"	,3.5  ,"mm"  ,3   ,6    ,55  ,6    ,0   ,4  ,0,nil))
			@@drillbitTbl.push(DrillBit.new("#9"	 ,"Up"	,3	  ,"mm"  ,8   ,6    ,45  ,6    ,0   ,4  ,0,nil))
			@@drillbitTbl.push(DrillBit.new("#10"	 ,"Up"	,2.5  ,"mm"  ,7   ,6    ,52  ,6    ,0   ,4  ,0,nil))
			@@drillbitTbl.push(DrillBit.new("#11"	 ,"Up"	,2	  ,"mm"  ,7   ,6    ,51  ,6    ,0   ,4  ,0,nil))
			@@drillbitTbl.push(DrillBit.new("#12"    ,"Down",1.5  ,"mm"  ,43.4,6    ,1.1 ,6    ,22.1,6.3,0,nil))
			@@drillbitTbl.push(DrillBit.new("#13"    ,"Down",5    ,"inch",43.4,2.1  ,1.1 ,9.4  ,22.1,6.3,7.1,nil))
			@@drillbitTbl.push(DrillBit.new("#14"    ,"Down",4    ,"inch",43.4,2.1  ,1.1 ,9.4  ,22.1,6.3,7.1,nil))
			@@drillbitTbl.push(DrillBit.new("#15"    ,"Down",7    ,"inch",43.4,2.1  ,1.1 ,9.4  ,22.1,6.3,7.1,nil))
			@@drillbitTbl.push(DrillBit.new("#16"    ,"Down",5    ,"mm"  ,43.4,2.1  ,1.1 ,9.4  ,22.1,6.3,7.1,nil))
			@@drillbitTbl.push(DrillBit.new("#17"    ,"Up"  ,5    ,"mm"  ,43.4,2.1  ,1.1 ,9.4  ,22.1,6.3,7.1,nil))
			@@drillbitTbl.push(DrillBit.new("#18"    ,"Down",5    ,"mm"  ,43.4,2.1  ,1.1 ,9.4  ,22.1,6.3,7.1,nil))
			@@drillbitTbl.push(DrillBit.new("#19"    ,"Down",5    ,"mm"  ,43.4,2.1  ,1.1 ,9.4  ,22.1,6.3,7.1,nil))
			@@drillbitTbl.push(DrillBit.new("#20"    ,"Down",5    ,"mm"  ,43.4,2.1  ,1.1 ,9.4  ,22.1,6.3,7.1,nil))
			@@drillbitTbl.push(DrillBit.new("#21"    ,"Down",5    ,"mm"  ,43.4,2.1  ,1.1 ,9.4  ,22.1,6.3,7.1,nil))
			nil
		end
		
		def self.saveToFile(filename)
			file = File.open(filename, "w")
			@@drillbitTbl.each { |drillbit|
				drillbit.saveToFile(file)
			}
			file.close
		end
		
		def self.loadFromFile(filename,append = false)
			if (!append)
				@@drillbitTbl = []
			end
			File.foreach(filename) { |line| 
				drillbit = DrillBit.new()
				drillbit.loadFromFile(line)
				@@drillbitTbl.push(drillbit)
			}
		end
		
		def show_dialog
			if @dialog && @dialog.visible?
				self.update_dialog
				@dialog.set_size(1200,700)
				@dialog.center # New feature!
				@dialog.bring_to_front
			else
				# Attach content and callbacks when showing the dialog,
				# not when creating it, to be able to use the same dialog again.
				@dialog ||= self.create_dialog
				@dialog.add_action_callback("ready") { |action_context|
					self.update_dialog
					nil
				}
				@dialog.add_action_callback("accept") { |action_context, value|
					@@drillbitSel = value
					@@drillbitTbl = @newdrillbitTbl.clone
					(0 .. @newdrillbitTbl.count - 1).each { |index|
						@@drillbitTbl[index] = @newdrillbitTbl[index].dup
					}
					@dialog.close
					nil
				}
				@dialog.add_action_callback("cancel") { |action_context, value|
					@dialog.close
					nil
				}
				@dialog.add_action_callback("apply") { |action_context, value|
					DrillBits.loadFromFile(File.join(GNTools::PATH_ROOT, "DrillBits.txt"))
					scriptStr = "delRowsTable()"
					@dialog.execute_script(scriptStr)
					self.update_dialog
					nil
				}
				@dialog.add_action_callback("save") { |action_context, value|
					@@drillbitTbl = @newdrillbitTbl.clone
					(0 .. @newdrillbitTbl.count - 1).each { |index|
						@@drillbitTbl[index] = @newdrillbitTbl[index].dup
					}
					DrillBits.saveToFile(File.join(GNTools::PATH_ROOT, "DrillBits.txt"))
					nil
				}
				@dialog.add_action_callback("tableAdjust") { |action_context, value,row|
					if @newdrillbitTbl.count - 1 < row
						@newdrillbitTbl.push(DrillBit.new())
						scriptStr = "delRowsTable()"
						@dialog.execute_script(scriptStr)
						@newdrillbitTbl.each { |oneDrill|
							scriptStr = "addRowToTable(\'#{oneDrill.to_Json()}\')"
							@dialog.execute_script(scriptStr)
						}
					end
				}
				@dialog.add_action_callback("changeValue") { |action_context, value,row|
#					@@drillbitTbl[row-1].from_Hash(value);
					@newdrillbitTbl[row-1].from_Hash(value);
					nil
				}
				@dialog.add_action_callback("load_profile") { |ctx, row|
				  drill = @newdrillbitTbl[row - 1]
				  sel = Sketchup.active_model.selection

				  if sel.empty?
					UI.messagebox("Select a group or edges to load a tool profile")
					next
				  end

				  profile = drill.profile_from_geometry(sel.to_a)

				  # Vérification type et valeur
				  profile.each_with_index do |pt, i|
				    puts "Point #{i}: x=#{pt[0]} (#{pt[0].class}), z=#{pt[1]} (#{pt[1].class})"
				  end

				  if profile.empty?
					UI.messagebox("No valid profile geometry found")
					next
				  end

				  drill.tool_profile = profile
				  UI.messagebox("Tool profile loaded (#{profile.size} points)")
				  nil
				}

				@dialog.add_action_callback("edit_profile") { |ctx, row|
				  drill = @newdrillbitTbl[row - 1]

				  if drill.tool_profile.nil? || drill.tool_profile.empty?
					UI.messagebox("No tool profile defined")
					next
				  end

				  drill.profile_to_group(
					drill.tool_profile,
					name: "ToolProfile - #{drill.name}"
				  )
				  nil
				}
				
				@dialog.set_size(1200,700)
				@dialog.center # New feature!
				@dialog.show
			end
		end

		def create_dialog
			html_file = File.join(GNTools::PATH_ROOT, 'ui', 'html', 'DrillBits.html') # Use external HTML
			options = {
			  :dialog_title => "DrillBits Settings",
			  :resizable => true,
			  :width => 1200,
			  :height => 700,
			  :preferences_key => "example.htmldialog.materialinspector",
			  :style => UI::HtmlDialog::STYLE_UTILITY  # New feature!
			}
			dialog = UI::HtmlDialog.new(options)
			dialog.set_file(html_file) # Can be set here.
			dialog.center # New feature!
			dialog.set_can_close { true }
			dialog
		end

		def update_dialog
			@newdrillbitTbl = @@drillbitTbl.clone
			(0 .. @@drillbitTbl.count - 1).each { |index|
				@newdrillbitTbl[index] = @@drillbitTbl[index].dup
			}
			@@drillbitTbl.each { |oneDrill|
				scriptStr = "addRowToTable(\'#{oneDrill.to_Json()}\')"
				@dialog.execute_script(scriptStr)
			}
		end
	end
end  #module GNTools
